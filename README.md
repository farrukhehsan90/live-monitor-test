# ML360 Video Call Application (Live Monitor)
This is a flutter project that facilitates a video call between people in the same ML360 session

## Getting Started
In order to set up your development environment, you must do the following:
1. Install the *latest* version of Flutter
2. Install Rust
3. Install LLVM (Not 100% sure if this is required, but if you run into issues you should make sure it is installed)

This project uses the rust-in-flutter library to integrate native Rust code into this Flutter application. This allows us to have low-latentcy, performant, live playback of audio that is streamed into the application from the ML360 JUCE plugin.