<img src="https://github.com/kylebshr/DexcomMenu/assets/3526783/2c3e5c01-cda8-4e1b-999c-dba829b9833e" data-canonical-src="https://github.com/kylebshr/DexcomMenu/assets/3526783/2c3e5c01-cda8-4e1b-999c-dba829b9833e" width="44" height="44" />

# DexcomMenu

Simple macOS menu bar app that uses [dexcom-vapor](http://github.com/kylebshr/dexcom-vapor) to display real-time Dexcom CGM readings. Requires macOS Sonoma or later.

![Screenshot 2024-04-12 at 3 18 32 PM](https://github.com/kylebshr/DexcomMenu/assets/3526783/fcbe8a2a-87fa-4e7c-a80c-ac4057a00a73)

## Getting started

### 1. Enable Sharing

For the Dexcom API to work, you must have sharing enabled with at least one person signed up to view your readings. You can invite yourself if you don’t want to actually share.

### 2. Download or Build

You can download the latest release from the [releases](https://github.com/kylebshr/DexcomMenu/releases) page, or clone this repo and build the app yourself.

### 3. Allow Keychain Access

DexcomMenu stores your username and password securely in the Keychain. You must grant keychain access when the app is opened for the first time. The app can only access keychain items it stores itself!

![Screenshot 2024-04-12 at 4 05 09 PM](https://github.com/kylebshr/DexcomMenu/assets/3526783/c456e26a-e7e5-4f39-87a0-819039403b1e)

### 4. Log In

You should be prompted to log in. Enter your _normal_ dexcom account details - _not_ the accout you’re sharing with. If your user ID is your phone number, sadly the API does not work. You can create a new Dexcom account with your email to use the API.

![Screenshot 2024-04-12 at 4 10 13 PM](https://github.com/kylebshr/DexcomMenu/assets/3526783/edc4ac93-1b21-4edd-ba54-9aced6620252)

Once you click Log In the menu bar app should start updating!
