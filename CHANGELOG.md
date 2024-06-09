## 1.4.2 - 14.05.2024 fix for https://github.com/escamoteur/watch_it/issues/29
## 1.4.1 - 23.03.2024
* fix for https://github.com/escamoteur/watch_it/issues/28
## 1.4.0 - 23.01.2024
* thanks to the pr https://github.com/escamoteur/watch_it/pull/27 by @jefflongo `pushScope` now accepts the `isFinal` parameter that the underlying get_it function does for some time now.
## 1.3.0 - 18.01.2024
* added `executeHandlerOnlyOnce` to `registerFutureHandler`, `allReady` and `allReadyHandler`
* added new functions: `callOnce` and `onDispose`. See readme for details
## 1.2.0 - 27.12.2023
* thanks to the PR from @smjxpro https://github.com/escamoteur/watch_it/pull/22 you now can register handlers for pure Listenable/ChangeNotifiers too
## 1.1.0 - 08.11.2023
* https://github.com/fluttercommunity/get_it/issues/345 `allReady()` will now throw a correct error if an exception is thrown in one of the factory functions that `allReady()` checks
## 1.0.6 - 31.10.2023 
* Typo fixes by PRs from @mym0404 @elitree @florentmx 
## 1.0.5 

* updates Discord invite link
## 1.0.4
* added some more asserts to provide better error messages in case you forgot to use the WatchItMixin
## 1.0.3
* bumped get_it version
## 1.0.2
* thanks for PR by @yangsfang https://github.com/escamoteur/watch_it/pull/10
## 1.0.1 
* small change in documentation
## 1.0.0
* fix for https://github.com/escamoteur/watch_it/issues/8
* improved comments thanks to PR by @kevlar700 
## 0.9.3
* added safety checks in case _element gets null but still a handler might get called
## 0.9.2
* improving readme
## 0.9.1
 * fix typo
## 0.9.0
* First beta release
## 0.0.1

* This is currently just a placeholder for the new version of the get_it_mixin
