#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include <string.h>

#include "lib-hiredis.h"
#include "lib-net.h"
#include "lib-sds.h"

typedef struct redhi_obj {
  redisContext *context;
} redhi_obj;

typedef redhi_obj *Redis__hiredis;

MODULE = Redis::hiredis PACKAGE = Redis::hiredis PREFIX = redis_hiredis_

SV *
redis_hiredis_connect(self, hostname, port=6379)
  Redis::hiredis self
  char *hostname
  int port
  CODE:
    self->context = redisConnect(hostname, port);
    if ( self->context->err ) {
      RETVAL = newSVpvn(self->context->errstr, strlen(self->context->errstr));
    }
    else {
      RETVAL = newSV(1);
    }
  OUTPUT:
    RETVAL

SV *
redis_hiredis_command(self, cmd)
  Redis::hiredis self
  char *cmd
  PREINIT:
    AV *arr_reply;
    redisReply *reply;
    int i;
  CODE:
        reply = redisCommand(self->context, cmd);
        if ( reply->type == REDIS_REPLY_ERROR 
            || reply->type == REDIS_REPLY_STRING 
            || reply->type == REDIS_REPLY_STATUS ) 
        {
            RETVAL = newSVpvn(reply->str,reply->len);
        }
        else if ( reply->type == REDIS_REPLY_ARRAY) {
            arr_reply = newAV();
            for ( i=0; i<reply->elements; i++ ) {
                if ( reply->element[i]->type == REDIS_REPLY_ERROR
                    || reply->element[i]->type == REDIS_REPLY_STRING 
                    || reply->element[i]->type == REDIS_REPLY_STATUS )
                {
                    av_push(arr_reply, 
                        newSVpvn(reply->element[i]->str, reply->element[i]->len)
                    );
                }
                else if ( reply->element[i]->type == REDIS_REPLY_INTEGER ) {
                    av_push(arr_reply, newSViv(reply->element[i]->integer));
                }
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
    redisFree(self->context);
