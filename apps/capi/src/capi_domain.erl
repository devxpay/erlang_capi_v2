-module(capi_domain).

-include_lib("damsel/include/dmsl_domain_thrift.hrl").
-include_lib("damsel/include/dmsl_domain_config_thrift.hrl").

-export([get_categories/0]).
-export([get_payment_institutions/0]).
-export([head/0]).
-export([all/1]).
-export([get/1]).
-export([get/2]).

-type revision() :: pos_integer().
-type ref() :: dmsl_domain_thrift:'Reference'().
-type data() :: _.

-type category() :: #domain_CategoryObject{}.
-type payment_institution() :: #domain_PaymentInstitutionObject{}.

-spec get_categories() -> {ok, [category()]}.
get_categories() ->
    Domain = all(head()),
    Categories = maps:fold(
        fun
            ({'category', _}, {'category', CategoryObject}, Acc) ->
                [CategoryObject | Acc];
            (_, _, Acc) ->
                Acc
        end,
        [],
        Domain
    ),
    {ok, Categories}.

-spec get_payment_institutions() -> {ok, [payment_institution()]}.
get_payment_institutions() ->
    % All this mess was done to reduce requests to dominant.
    % TODO rewrite this with dmt_client, cache, unicorns and rainbows.
    Domain = all(head()),
    Ref = {globals, #domain_GlobalsRef{}},
    {ok, {globals, #domain_GlobalsObject{data = Globals}}} = dmt_domain:get_object(Ref, Domain),
    {ok, get_payment_institutions(Globals, Domain)}.

get_payment_institutions(#domain_Globals{payment_institutions = PaymentInstitutionRefs}, Domain) when
    PaymentInstitutionRefs /= undefined
->
    lists:map(
        fun(Ref) ->
            {ok, {payment_institution, Object}} = dmt_domain:get_object({payment_institution, Ref}, Domain),
            Object
        end,
        ordsets:to_list(PaymentInstitutionRefs)
    );
get_payment_institutions(#domain_Globals{payment_institutions = undefined}, _) ->
    [].

-spec head() -> revision().
head() ->
    dmt_client:get_last_version().

-spec all(revision()) -> dmsl_domain_thrift:'Domain'().
all(Revision) ->
    #'Snapshot'{domain = Domain} = dmt_client:checkout({version, Revision}),
    Domain.

-spec get(ref()) -> {ok, data()} | {error, not_found}.
get(Ref) ->
    Revision = head(),
    get(Revision, Ref).

-spec get(revision(), ref()) -> {ok, data()} | {error, not_found}.
get(Revision, Ref) ->
    try
        {ok, extract_object(dmt_client:checkout_object({version, Revision}, Ref))}
    catch
        throw:#'ObjectNotFound'{} ->
            {error, not_found}
    end.

extract_object(#'VersionedObject'{object = {_Tag, Object}}) ->
    Object.
