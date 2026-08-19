Welcome to the Stiletto Swift Prototype playtest!

Here's how to get your game client and updater set up.

-Grab the updater and archive packages from the itch page.
-Extract the updater first. You'll see a game folder. This is where the archive contents will go.
-Extract the stiletto-proto.7z assets to the game folder.
-You can now run the updater and fetch the newest engine binaries, plugins, WebCore ICU data (game/resources/icudt67l.dat), compiled game progs, decls, web UI, and updater self-patches. Without that ICU file the HUD crashes a few seconds after map load.
-The Qt runtime (runtime/qml.exe and bundled QML) is not delivered by the updater; it ships with the itch updater package.


Maps, models, sound, textures, music, and similar assets are not updater-delivered. Join-download still fetches maps, sounds, models, and the like from the host server (that's mine) when you connect, and we'll see how it goes.

And please, if you can, write down your feedback.

Thank you so much for testing this project!