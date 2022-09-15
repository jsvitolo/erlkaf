-module(erlkaf_app).

-include("erlkaf_private.hrl").

-behaviour(application).

-export([
    start/2,
    stop/1
]).

start(_StartType, _StartArgs) ->
    ?LOG_INFO("STARTANDO", []),
    ok = erlkaf_cache_client:create(),
    {ok, Pid} = erlkaf_sup:start_link(),
    ok = start_clients(),
    {ok, Pid}.

stop(_State) ->
    ok.

start_clients() ->
    case erlkaf_utils:get_env(clients) of
        undefined ->
            ok;
        Value ->
            ok = lists:foreach(fun(Client) -> start_client(Client) end, Value)
    end.

start_client({ClientId, C}) ->
    Type = erlkaf_utils:lookup(type, C),
    ClientOpts = erlkaf_utils:lookup(client_options, C, []),
    Topics = erlkaf_utils:lookup(topics, C, []),
    ?LOG_INFO("STONE START CLIENT: ~p", [ClientOpts]),

    case Type of
        producer ->
            ok = erlkaf:create_producer(ClientId, ClientOpts),
            ?LOG_INFO("producer ~p created", [ClientId]),
            ok = create_topics(ClientId, Topics);
        consumer ->
            GroupId = erlkaf_utils:lookup(group_id, C),
            DefaultTopicsConfig = erlkaf_utils:lookup(topic_options, C, []),
            ok = erlkaf:create_consumer_group(ClientId, GroupId, Topics, ClientOpts, DefaultTopicsConfig),
            ?LOG_INFO("consumer ~p created", [ClientId])
    end.

create_topics(ClientId, [H|T]) ->
    case H of
        {TopicName, TopicOpts} ->
            ok = erlkaf:create_topic(ClientId, TopicName, TopicOpts),
            ?LOG_INFO("topic ~p created over client: ~p", [TopicName, ClientId]);
        TopicName when is_binary(TopicName) ->
            ok = erlkaf:create_topic(ClientId, TopicName),
            ?LOG_INFO("topic ~p created over client: ~p", [TopicName, ClientId])
    end,
    create_topics(ClientId, T);
create_topics(_ClientId, []) ->
    ok.