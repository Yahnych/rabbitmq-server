%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ Management Plugin.
%%
%%   The Initial Developer of the Original Code is GoPivotal, Inc.
%%   Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.

-module(rabbit_mgmt_wm_consumers).

-export([init/3, rest_init/2, to_json/2, content_types_provided/2, resource_exists/2,
         is_authorized/2]).
-export([variances/2]).

-import(rabbit_misc, [pget/2]).

-include("rabbit_mgmt.hrl").
-include("rabbit_mgmt_metrics.hrl").
-include_lib("rabbit_common/include/rabbit.hrl").

%%--------------------------------------------------------------------

init(_, _, _) -> {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Config) ->
    {ok, rabbit_mgmt_cors:set_headers(Req, ?MODULE), #context{}}.

variances(Req, Context) ->
    {[<<"accept-encoding">>, <<"origin">>], Req, Context}.

content_types_provided(ReqData, Context) ->
   {[{<<"application/json">>, to_json}], ReqData, Context}.

resource_exists(ReqData, Context) ->
    {case rabbit_mgmt_util:vhost(ReqData) of
         not_found -> false;
         none -> true; % none means `all`
         _  -> true
     end, ReqData, Context}.

to_json(ReqData, Context = #context{user = User}) ->
    Arg = case rabbit_mgmt_util:vhost(ReqData) of
              none  -> all;
              VHost -> VHost
          end,

    Consumers = lists:map(fun rabbit_mgmt_format:clean_consumer/1,
                          rabbit_mgmt_db:get_all_consumers(Arg)),
    rabbit_mgmt_util:reply_list(
      filter_user(Consumers, User), ReqData, Context).

is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized(ReqData, Context).

filter_user(List, #user{username = Username, tags = Tags}) ->
    case rabbit_mgmt_util:is_monitor(Tags) of
        true  -> List;
        false -> [I || I <- List,
                       pget(user, pget(channel_details, I)) == Username]
    end.
