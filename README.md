# [WIP] substitution 
This is an art project to substitute the social networks with an real social network.
Substitution is a static web (and soon android/ios) app, based on the matrix protocol.

Its main feature:
=> decentralized servers

For content creators:
=> Fine graded posting control: Only Accounts with power level > 50 can post
=> Post images, videos and html with a wysiwyg editor (and more to come)
=> Link to your room via https://app.substitution.art/#/feed/:roomId where :roomId is the room id or alias (last one without the leading #)

For followers:
=> Follow any room on any server
=> Search for rooms on servers

For anyone:
=> Link to any room on any matrix server:
https://app.substitution.art/#/room/:roomId

For first expressions, look at: https://app.substitution.art/#/feed/photo_art:matrix.org

# Big TODOs:
- Fix 
- Translations

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
