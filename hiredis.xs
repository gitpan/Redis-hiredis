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
} redhi_obj;

typedef redhi_obj *Redis__hiredis;

SV * _readReply (redisReply *reply);
SV * _readMultiBulkReply (redisReply *reply);
SV * _readBulkReply (redisReply *reply);

SV * _readReply (redisReply *reply) {
    if (reply->type == REDIS_REPLY_ARRAY) {
        return _readMultiBulkReply(reply);
    }
    else {
        return _readBulkReply(reply);
    }
}

SV * _readMultiBulkReply (redisReply *reply) {
    SV *sv;
    AV *arr_reply;
    int i;
    arr_reply = newAV();
    for ( i=0; i < reply->elements; i++) {
        av_push(arr_reply, _readBulkReply(reply->element[i]));
    }
    sv = newRV_inc((SV*)arr_reply);

    return sv;
}

SV * _readBulkReply (redisReply *reply) {
    SV *sv;

    if ( reply->type == REDIS_REPLY_ERROR ) {
        croak("%s",reply->str);
    }
    else if ( reply->type == REDIS_REPLY_STRING 
           || reply->type == REDIS_REPLY_STATUS ) {
        sv = newSVpvn(reply->str,reply->len);
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
redis_hiredis_connect(self, hostname, port=6379)
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
    char *cmd
    PREINIT:
        redisReply *reply;
    CODE:
        assertConnected(self);
        reply  = redisCommand(self->context, cmd);
        RETVAL = _readReply(reply);
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
        RETVAL = _readReply(reply);
        freeReplyObject(reply);
    OUTPUT:
        RETVAL

Redis::hiredis
redis_hiredis_new(clazz)
    char *clazz
    CODE:
        RETVAL = calloc(1, sizeof(struct redhi_obj));
    OUTPUT:
        RETVAL

void
redis_hiredis_DESTROY(self)
    Redis::hiredis self
    CODE:
        if ( self->context != NULL )
            redisFree(self->context);
