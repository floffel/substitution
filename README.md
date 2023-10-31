# [WIP] substitution 

almost deployed - stay tuned for updates...


On gentoo, it requires dev-libs/olm to run.

run: flutter run
or make

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
