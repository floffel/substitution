# [WIP] substitution 
This is an art project to substitute the social networks with an real social network.
Substitution is a static web (and soon android/ios) app, based on the matrix protocol.

Its main feature:
=> decentralized servers
=> e2e encrypted rooms are possible (though no metadata encryption, the server owner will see the rooms you joined, not the posts you send/read)

For content creators:
=> Fine graded posting control: Only Accounts with power level > 50 can post
=> Post images, videos and html with a wysiwyg editor (and more to come)
=> Link to your room via https://app.substitution.art/#/feed/:roomId where :roomId is the room id or alias (last one without the leading #)
   (users have to be logged in though, this is a limitation by the matrix protocol)

For followers:
=> Comment and React on Posts and Comments
=> Follow any room on any server
=> Search for rooms on servers

For first expressions, look at: https://app.substitution.art/#/feed/photo_art:matrix.org (you have to be logged in first)

# Big TODOs:
- Fix 
- Rewrite translations to use singular or plural, not both/mixed

# Prerequirements for run/build:
On gentoo, it requires dev-libs/olm to run.
```
git clone https://github.com/floffel/flutter-emoji-selector     # until changes merged
git clone https://github.com/floffel/introduction_screen        # until changes merged
git clone https://github.com/floffel/substitution               # this repo
```

# Building:
```
pushd substitution # switch into this repo
flutter build
popd
```

# Running:
```
pushd substitution # switch into this repo
flutter run
popd
```

or (if you are on my machine): ```make```


### TODOs
Most todos are inside the code, just ```grep -Ri "TODO"``` to get a list.

### Code style TODOs:
- Refactor all Tuples from
```
List<(Event, Timeline)> newEvents = [];
```
to look like
```
List<{(Event event, Timeline timeline)}> newEvents = [];
```
to go from
```
newEvents[i].$1
```
to the more readable
```
newEvents[i].event
```
for every i in ```newEvents.length```
