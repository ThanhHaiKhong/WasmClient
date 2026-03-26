@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Livescore

extension WasmActor {

    // MARK: - Generic Helper

    /// Run a livescore request and decode the proto response.
    private func runLivescore<T: SwiftProtobuf.Message>(
        endpoint: LivescoreEndpoint,
        params: [String: String] = [:]
    ) async throws -> T {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.livescore.rawValue, logger: logger)
        var args: [String: Google_Protobuf_Value] = [
            "endpoint": Google_Protobuf_Value(numberValue: Double(endpoint.rawValue)),
        ]
        for (k, v) in params {
            args[k] = Google_Protobuf_Value(stringValue: v)
        }
        let task = try await instance.create(action: action, args: args)
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        return try T(unpackingAny: task.value)
    }

    // MARK: - Livescores

    func livescores(type: String) async throws -> [WasmClient.Fixture] {
        let list: LivescoreFixtureList = try await runLivescore(
            endpoint: .livescores, params: ["type": type]
        )
        return list.fixtures.map(mapFixture)
    }

    func fixtures(date: String) async throws -> [WasmClient.Fixture] {
        let list: LivescoreFixtureList = try await runLivescore(
            endpoint: .fixtures, params: ["date": date]
        )
        return list.fixtures.map(mapFixture)
    }

    func fixture(id: String) async throws -> [WasmClient.Fixture] {
        let list: LivescoreFixtureList = try await runLivescore(
            endpoint: .fixtures, params: ["id": id]
        )
        return list.fixtures.map(mapFixture)
    }

    func headToHead(team1: String, team2: String) async throws -> [WasmClient.Fixture] {
        let list: LivescoreFixtureList = try await runLivescore(
            endpoint: .h2H, params: ["team1_id": team1, "team2_id": team2]
        )
        return list.fixtures.map(mapFixture)
    }

    // MARK: - Leagues

    func leagues() async throws -> [WasmClient.League] {
        let list: LivescoreLeagueList = try await runLivescore(endpoint: .leagues)
        return list.leagues.map(mapLeague)
    }

    func searchLeagues(query: String) async throws -> [WasmClient.League] {
        let list: LivescoreLeagueList = try await runLivescore(
            endpoint: .leagues, params: ["search": query]
        )
        return list.leagues.map(mapLeague)
    }

    func league(id: String) async throws -> [WasmClient.League] {
        let list: LivescoreLeagueList = try await runLivescore(
            endpoint: .leagues, params: ["id": id]
        )
        return list.leagues.map(mapLeague)
    }

    // MARK: - Standings

    func standings(seasonID: String) async throws -> [WasmClient.Standing] {
        let list: LivescoreStandingList = try await runLivescore(
            endpoint: .standings, params: ["season_id": seasonID]
        )
        return list.standings.map(mapStanding)
    }

    // MARK: - Teams

    func searchTeams(query: String) async throws -> [WasmClient.Team] {
        let list: LivescoreTeamList = try await runLivescore(
            endpoint: .teams, params: ["search": query]
        )
        return list.teams.map(mapTeam)
    }

    func team(id: String) async throws -> [WasmClient.Team] {
        let list: LivescoreTeamList = try await runLivescore(
            endpoint: .teams, params: ["id": id]
        )
        return list.teams.map(mapTeam)
    }

    // MARK: - Players

    func searchPlayers(query: String) async throws -> [WasmClient.Player] {
        let list: LivescorePlayerList = try await runLivescore(
            endpoint: .players, params: ["search": query]
        )
        return list.players.map(mapPlayer)
    }

    func player(id: String) async throws -> [WasmClient.Player] {
        let list: LivescorePlayerList = try await runLivescore(
            endpoint: .players, params: ["id": id]
        )
        return list.players.map(mapPlayer)
    }

    // MARK: - Topscorers

    func topscorers(seasonID: String) async throws -> [WasmClient.Player] {
        let list: LivescoreTopscorerList = try await runLivescore(
            endpoint: .topscorers, params: ["season_id": seasonID]
        )
        return list.topscorers.compactMap { ts in
            guard ts.hasPlayer else { return nil }
            return mapPlayer(ts.player)
        }
    }

    // MARK: - Predictions / Odds / Expected / News (raw Data)

    func predictions(fixtureID: String) async throws -> Data {
        let list: LivescorePredictionList = try await runLivescore(
            endpoint: .predictions, params: ["fixture_id": fixtureID]
        )
        return try list.serializedData()
    }

    func odds(fixtureID: String, type: String) async throws -> Data {
        let list: LivescoreOddList = try await runLivescore(
            endpoint: .odds, params: ["fixture_id": fixtureID, "type": type]
        )
        return try list.serializedData()
    }

    func expectedGoals(fixtureID: String, type: String) async throws -> Data {
        let list: LivescoreExpectedMetricList = try await runLivescore(
            endpoint: .expected, params: ["fixture_id": fixtureID, "type": type]
        )
        return try list.serializedData()
    }

    func news(seasonID: String, type: String) async throws -> Data {
        let list: LivescoreNewsList = try await runLivescore(
            endpoint: .news, params: ["season_id": seasonID, "type": type]
        )
        return try list.serializedData()
    }

    // MARK: - Highlights

    func highlights(competition: String?, team: String?) async throws -> [WasmClient.Highlight] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.lsHighlights.rawValue, logger: logger)
        var args: [String: Google_Protobuf_Value] = [:]
        if let c = competition { args["competition"] = Google_Protobuf_Value(stringValue: c) }
        if let t = team { args["team"] = Google_Protobuf_Value(stringValue: t) }
        let task = try await instance.create(action: action, args: args)
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let list = try LivescoreHighlightList(unpackingAny: task.value)
        return list.highlights.map(mapHighlight)
    }

    // MARK: - Livescore Mapping

    private func mapFixture(_ f: LivescoreFixture) -> WasmClient.Fixture {
        let homeScore: Int? = f.hasScores && f.scores.hasFulltime ? Int(f.scores.fulltime.home) : nil
        let awayScore: Int? = f.hasScores && f.scores.hasFulltime ? Int(f.scores.fulltime.away) : nil
        return WasmClient.Fixture(
            id: f.id,
            homeTeam: f.hasHomeTeam ? f.homeTeam.name : (f.participants.first?.name ?? ""),
            awayTeam: f.hasAwayTeam ? f.awayTeam.name : (f.participants.count > 1 ? f.participants[1].name : ""),
            homeScore: homeScore,
            awayScore: awayScore,
            status: f.statusShort,
            date: f.startingAt,
            league: f.hasLeague ? f.league.name : "",
            round: f.roundName
        )
    }

    private func mapLeague(_ l: LivescoreLeague) -> WasmClient.League {
        WasmClient.League(
            id: l.id,
            name: l.name,
            country: l.hasCountry ? l.country.name : "",
            logo: l.logoURL,
            type: "\(l.type)"
        )
    }

    private func mapTeam(_ t: LivescoreTeam) -> WasmClient.Team {
        WasmClient.Team(
            id: t.id,
            name: t.name,
            logo: t.logoURL,
            country: t.hasCountry ? t.country.name : t.countryName
        )
    }

    private func mapStanding(_ s: LivescoreStanding) -> WasmClient.Standing {
        WasmClient.Standing(
            rank: Int(s.position),
            teamID: s.participantID,
            teamName: s.hasParticipant ? s.participant.name : "",
            points: Int(s.points),
            played: s.hasAll ? Int(s.all.played) : 0,
            won: s.hasAll ? Int(s.all.win) : 0,
            drawn: s.hasAll ? Int(s.all.draw) : 0,
            lost: s.hasAll ? Int(s.all.lose) : 0,
            goalsFor: s.hasAll ? Int(s.all.goalsFor) : 0,
            goalsAgainst: s.hasAll ? Int(s.all.goalsAgainst) : 0
        )
    }

    private func mapPlayer(_ p: LivescorePlayer) -> WasmClient.Player {
        WasmClient.Player(
            id: p.id,
            name: p.displayName.isEmpty ? p.name : p.displayName,
            position: "\(p.position)",
            nationality: p.nationality,
            photo: p.photoURL
        )
    }

    private func mapHighlight(_ h: LivescoreScorebatVideoFeed) -> WasmClient.Highlight {
        WasmClient.Highlight(
            title: h.title,
            videoURL: h.matchviewURL,
            thumbnailURL: h.thumbnail,
            competition: h.competition,
            date: h.date
        )
    }
}
