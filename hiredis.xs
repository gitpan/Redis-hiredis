#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include <string.h>

#include "lib-hiredis.h"
#include "lib-anet.h"
#include "lib-sds.h"

typedef struct redhi_obj {
  int fd;       // file descriptor of connection
} redhi_obj;

typedef redhi_obj *Redis__hiredis;

MODULE = Redis::hiredis PACKAGE = Redis::hiredis PREFIX = redis_hiredis_

SV *
redis_hiredis_connect(self, hostname, port=6379)
  Redis::hiredis self
  char *hostname
  int port
  PREINIT:
    redisReply *reply;
  CODE:
    reply = redisConnect(&self->fd, hostname, port);
    if ( reply != NULL ) {
      RETVAL = newSVpvn(reply->reply, strlen(reply->reply));
      freeReplyObject(reply);
    }
    else {
      RETVAL = newSV(0);
    }
  OUTPUT:
    RETVAL

SV *
redis_hiredis_command(self, arr_ref)
  Redis::hiredis self
  SV *arr_ref
  PREINIT:
    AV *array;
    AV *arr_reply;
    int i;
    sds cmd;
    const char *ccurr;
    redisReply *reply;
  CODE:
    if ( SvROK(arr_ref) ) {
        if ( SvTYPE(array = (AV*)SvRV(arr_ref))==SVt_PVAV ) {
            cmd = sdsempty();
            cmd = sdscatprintf(cmd,"*%d\r\n",(int)av_len(array)+1);
            for ( i=0; i<av_len(array)+1; i++ ) {
                SV **curr = av_fetch(array,i,0);
                if ( curr != NULL ) {
                    ccurr = SvPV_nolen(*curr);
                    sds s = sdsnew(ccurr);
                    cmd = sdscatprintf(cmd, "$%zu\r\n", sdslen(s));
                    cmd = sdscatlen(cmd, s, sdslen(s));
                    cmd = sdscatlen(cmd, "\r\n", 2); 
                    sdsfree(s);
                }
            }
            anetWrite(self->fd, cmd, sdslen(cmd));
            sdsfree(cmd);
            reply = redisReadReply(self->fd);
            if ( reply->type == REDIS_REPLY_ERROR 
                || reply->type == REDIS_REPLY_STRING ) 
            {
                RETVAL = newSVpvn(reply->reply,strlen(reply->reply));
            }
            else if ( reply->type == REDIS_REPLY_ARRAY) {
                arr_reply = newAV();
                for ( i=0; i<reply->elements; i++ ) {
                    av_push(arr_reply, 
                        newSVpvn(reply->element[i]->reply, strlen(reply->element[i]->reply))
                    );
                }
                RETVAL = newRV_inc((SV*)arr_reply);
            }
            else if ( reply->type == REDIS_REPLY_INTEGER ) {
                RETVAL = newSViv(reply->integer);
            }
            else {
                // either REDIS_REPLY_NIL or something is awry
                RETVAL = newSV(0);
            }
            freeReplyObject(reply);
        }
    }
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
    if ( self->fd > 0 ) { 
        close(self->fd);
    }
