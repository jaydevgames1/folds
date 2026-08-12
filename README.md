# Folds

A unique symmetrical puzzle that'll leave you in Folds!

## About the Project

Folds is the new unique symmetrical puzzle that is a new twist on patterns and symmetry, beautiful things. From bite-sized 4x4 puzzles to beastly 12x12 puzzles (and every size in between), there's puzzles for everyone! Experience hundreds of puzzles with new puzzles every single day! Rack up XP and climb the leaderboard, grind out all the puzzles and mirror the tiles; all the better to leave you with Folds of fun!

You can get to know about Folds and more by visiting:

- [JayDev Games Website](https://jaydev.games)
- [Folds Website](https://folds.jaydev.games)

## Replication Notes (Prerequisites)
If you wish to duplicate the files, please change any imports in files under lib/* from  
```import package:folds/core/constants.example.dart```  
to  
```import package:folds/core/constants.dart```  

## Replication Notes (How to Run)
For best experience, use VSCode.  
- Download the zip file.
- Extract the file.
- Open the folder with VSCode (or your preferred IDE; be cautious as other IDEs may not be as reliable to run this project)
- Make sure you have Flutter & Dart extensions installed. The files will not run if you do not have this. The project consists of majority Dart, although the JavaScript majority Linguist detects is vastly inaccurate.
- For the first time running, make sure to run ```flutter pub get``` in your terminal; this gets any dependencies not installed in your PC.
- After the dependencies have been fetched, there are methods to run the app locally on your PC:
  - On Mac: Open Simulators, or open a specific one you wish. VSCode will automatically detect your simulator.
  - On Windows/Linux: Please visit Android studio and grab the SDKs to fetch your Android emulator.
- Once you have your simulator, double-check VSCode has detected your simulator by running ```flutter device``` (note that if you do not have any simulators attached (or VSCode cannot detect them), VSCode will try to run the application on your local browser- this won't work due to dimension capabilities set by the application. Automatically adjusting your browser size will not guarantee that the application will run as if on a phone.)
- If you have your simulator connected to VSCode, run ```flutter run``` in your terminal. This will fetch all the files and run them (on Mac) through VSCode to the simulator.
- Once the terminal diverts back to command prompt, and there are no errors (if there are, see below), your simulator will boot up the application for you to test out on. That's it!

## Replication Notes (Troubleshooting)
- If there is a problem with fetching simulators, please visit the corresponding [XCode/Mac](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) or [Android Studio/Windows, Linux](https://developer.android.com/studio/run/emulator) Docs to find your issue.
- Check if Dart and Flutter is correctly installed. Since the files are pre-set up to Flutter's standards, there should not be any SDK issues. If there are, visit [here](https://docs.flutter.dev/install).
- If running doesn't work, it's likely a Flutter outdated SDK problem. Run ```flutter upgrade``` to help fix the issue.
- If dependencies don't fetch, try running ```flutter pub upgrade``` to upgrade your dependencies to the latest version.
- For Mac, if the Product Scheme is set to Release, Flutter will not be able to run the project. An easy workaround is by trying ```flutter run --release``` however it is not incredibly reliable. Instead, open XCode -> Product -> Edit Scheme -> Debug 'Yes', Release 'No'. Please note if you are to simulate the application onto a physical device you need to revert the Product Scheme back to Release mode.
- On the first time loading up the simulator, the time it takes for the application to be transferred to the simulator can take five to fifty minutes, so please be patient if it is not working fast.
- If you have any more questions regarding Flutter, please visit [the Flutter website](https://flutter.dev/)
- Any specific questions regarding the actual project itself, please contact [JayDev Games](mailto:support@jaydev.games).

Happy Folding!
    

