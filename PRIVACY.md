# Privacy

Substitution is available on Android, iOS, web, windows, linux and macOs.

*   [Matrix](#matrix)
*   [Database](#database)
*   [Encryption](#encryption)
*   [App Permissions](#app-permissions)

## Matrix<a id="matrix"/>
Substitution uses the Matrix protocol. This means that Substitution is just a client that can be connected to any compatible matrix servers. The respective data protection agreement of the servers selected by the user then applies.

For convenience, one or more servers are set as default that the Substitution developers consider trustworthy. The developers of Substitution do not guarantee their trustworthiness. Before the first communication, users are informed which server they are connecting to.

FluffyChat only communicates with the selected servers.

More information is available at: [https://matrix.org](https://matrix.org)

## Database<a id="database"/>
Substitution caches some data received from the server in a local database on the device of the user.

More information is available at: [https://pub.dev/packages/hive](https://pub.dev/packages/hive)

## Encryption<a id="encryption"/>
All communication of substantive content between Substitution and any server is done in secure way, using transport encryption to protect it.

Substitution is able to use End-To-End-Encryption as a tech preview.

## App Permissions<a id="app-permissions"/>

The permissions are the same on Android and iOS but may differ in the name. This are the Android Permissions:

#### Internet Access
Substitution needs to have internet access to communicate with the Matrix Server.

#### Read External Storage
The user is able to send files from the device's file system.
