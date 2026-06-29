# Authentik Blueprint Quirks

Things that bit us when writing Authentik blueprints:

- OAuth2 authorize/token/userinfo URLs are **global**: `/application/o/authorize/` (no app slug in path)
- `redirect_uris` must be a list of objects: `[{url: "...", matching_mode: strict, type: authorization}]`, not plain strings
- `client_type: confidential` is required for apps with a client secret
- `invalidation_flow` is a required field (use `!Find` for `default-provider-invalidation-flow`)
- `logout_method` blueprint field only accepts `backchannel` even though UI shows "Front-channel"; logout works either way
- Worker task queue can get stuck (tasks enqueued but never processed) — `kubectl delete pod` fixes it
- `ak apply_blueprint` validates but actual save requires the Dramatiq task to process; worker restart + server restart needed for outpost sync

### Backchannel vs front-channel logout

Official [Grafana integration docs](https://integrations.goauthentik.io/monitoring/grafana/)
recommend setting the provider's **Logout Method** to `Front-channel`. However neither `front_channel`
nor `front` is accepted by the blueprint validator (only `backchannel` is valid). The UI may expose
a front-channel option that maps to a different internal value. Logout works correctly with
`backchannel` in practice — revisit this if issues arise. The internal enum is in
`authentik_providers_oauth2.models` → `LogoutMethod`.

