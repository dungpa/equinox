﻿module Samples.Store.Integration.ContactPreferencesIntegration

open Equinox.EventStore
open Equinox.MemoryStore
open Swensen.Unquote

#nowarn "1182" // From hereon in, we may have some 'unused' privates (the tests)

let fold, initial = Domain.ContactPreferences.Folds.fold, Domain.ContactPreferences.Folds.initial

let createMemoryStore () =
    new VolatileStore()
let createServiceMem log store =
    Backend.ContactPreferences.Service(log, fun _batchSize _eventTypePredicate -> MemoryStreamBuilder(store, fold, initial).Create)

let codec = genCodec<Domain.ContactPreferences.Events.Event>()
let resolveStreamGesWithCompactionSemantics gateway =
    fun windowSize predicate streamName ->
        GesStreamBuilder(gateway windowSize, codec, fold, initial, CompactionStrategy.Predicate predicate).Create(streamName)
let resolveStreamGesWithoutCompactionSemantics gateway =
    fun _windowSize _ignoreCompactionPredicate streamName ->
        GesStreamBuilder(gateway defaultBatchSize, codec, fold, initial).Create(streamName)

type Tests(testOutputHelper) =
    let testOutput = TestOutputAdapter testOutputHelper
    let createLog () = createLogger testOutput

    let act (service : Backend.ContactPreferences.Service) (id,value) = async {
        let (Domain.ContactPreferences.Id email) = id
        do! service.Update email value

        let! actual = service.Read email
        test <@ value = actual @> }

    [<AutoData>]
    let ``Can roundtrip in Memory, correctly folding the events`` args = Async.RunSynchronously <| async {
        let service = let log, store = createLog (), createMemoryStore () in createServiceMem log store
        do! act service args
    }

    let arrange connect choose resolveStream = async {
        let log = createLog ()
        let! conn = connect log
        let gateway = choose conn
        return Backend.ContactPreferences.Service(log, resolveStream gateway) }

    [<AutoData(SkipIfRequestedViaEnvironmentVariable="EQUINOX_INTEGRATION_SKIP_EVENTSTORE")>]
    let ``Can roundtrip against EventStore, correctly folding the events with normal semantics`` args = Async.RunSynchronously <| async {
        let! service = arrange connectToLocalEventStoreNode createGesGateway resolveStreamGesWithoutCompactionSemantics
        do! act service args
    }

    [<AutoData(SkipIfRequestedViaEnvironmentVariable="EQUINOX_INTEGRATION_SKIP_EVENTSTORE")>]
    let ``Can roundtrip against EventStore, correctly folding the events with compaction semantics`` args = Async.RunSynchronously <| async {
        let! service = arrange connectToLocalEventStoreNode createGesGateway resolveStreamGesWithCompactionSemantics
        do! act service args
    }
