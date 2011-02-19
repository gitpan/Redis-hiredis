#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include <string.h>
#include <stdio.h>

#include "lib-hiredis.h"
#include "lib-net.h"
#include "lib-sds.h"

typedef struct redhi_obj {
    redisContext *context;
    bool utf8;
} redhi_obj;

typedef redhi_obj *Redis__hiredis;

SV * _read_reply (Redis__hiredis self, redisReply *reply);
SV * _read_multi_bulk_reply (Redis__hiredis self, redisReply *reply);
SV * _read_bulk_reply (Redis__hiredis self, redisReply *reply);

SV * _read_reply (Redis__hiredis self, redisReply *reply) {
    if (reply->type == REDIS_REPLY_ARRAY) {
        return _read_multi_bulk_reply(self, reply);
    }
    else {
        return _read_bulk_reply(self, reply);
    }
}

SV * _read_multi_bulk_reply (Redis__hiredis self, redisReply *reply) {
    AV *arr_reply = newAV();
    SV *sv = newRV_noinc((SV*)arr_reply);
    int i;
    for ( i=0; i < reply->elements; i++) {
        av_push(arr_reply, _read_bulk_reply(self, reply->element[i]));
    }

    return sv;
}

SV * _read_bulk_reply (Redis__hiredis self, redisReply *reply) {
    SV *sv;

    if ( reply->type == REDIS_REPLY_ERROR ) {
        croak("%s",reply->str);
    }
    else if ( reply->type == REDIS_REPLY_STRING 
           || reply->type == REDIS_REPLY_STATUS ) {
        sv = newSVpvn(reply->str,reply->len);
        if (self->utf8) {
            sv_utf8_decode(sv);
        }
    }
    else if ( reply->type == REDIS_REPLY_INTEGER ) {
        sv = newSViv(reply->integer);
    }
    else {
        // either REDIS_REPLY_NIL or something is awry
        sv = newSV(0);
    }

    return sv;
}

void assertConnected (redhi_obj *self) {
    if (self->context == NULL) {
        croak("%s","Not connected.");
    }
}

MODULE = Redis::hiredis PACKAGE = Redis::hiredis PREFIX = redis_hiredis_

void
redis_hiredis_connect(self, hostname, port = 6379)
    Redis::hiredis self
    char *hostname
    int port
    CODE:
        self->context = redisConnect(hostname, port);
        if ( self->context->err ) {
            croak("%s",self->context->errstr);
        }

SV *
redis_hiredis_command(self, cmd)
    Redis::hiredis self
    SV *cmd
    PREINIT:
        int i;
        AV *array;
        char **argv;
        size_t *argv_sizes;
        redisReply *reply;
    CODE:
        assertConnected(self);
        if ( SvROK(cmd) && SvTYPE(array = (AV*)SvRV(cmd))==SVt_PVAV ) {
            argv = (char**)malloc((av_len(array) + 1) * sizeof(char *));
            argv_sizes = (size_t*)malloc((av_len(array) + 1) * sizeof(size_t *));
            for ( i = 0; i < av_len(array)+1; i++ ) {
                STRLEN len;
                SV **curr = av_fetch(array,i,0);
                if ( self->utf8 ) {
                    argv[i] = SvPVutf8(*curr, len);
                }
                else {
                    argv[i] = SvPV(*curr, len);
                }
                argv_sizes[i] = len;
            }
            reply  = redisCommandArgv(self->context, av_len(array) + 1, (const char **)argv, argv_sizes);
            free(argv);
            free(argv_sizes);
        }
        else {
            reply  = redisCommand(self->context, SvPV_nolen(cmd));
        }
        RETVAL = _read_reply(self, reply);
        freeReplyObject(reply);
    OUTPUT:
        RETVAL

void
redis_hiredis_append_command(self, cmd)
    Redis::hiredis self
    char *cmd
    CODE:
        assertConnected(self);
        redisAppendCommand(self->context, cmd);

SV *
redis_hiredis_get_reply(self)
    Redis::hiredis self
    PREINIT:
        redisReply *reply;
    CODE:
        assertConnected(self);
        redisGetReply(self->context, (void **) &reply);
        RETVAL = _read_reply(self, reply);
        freeReplyObject(reply);
    OUTPUT:
        RETVAL

Redis::hiredis
redis_hiredis__new(clazz, utf8)
    char *clazz
    bool utf8
    PREINIT:
        Redis__hiredis self;
    CODE:
        self = calloc(1, sizeof(struct redhi_obj));
        self->utf8 = utf8;
        RETVAL = self;
    OUTPUT:
        RETVAL

void
redis_hiredis_DESTROY(self)
    Redis::hiredis self
    CODE:
        if ( self->context != NULL )
            redisFree(self->context);
