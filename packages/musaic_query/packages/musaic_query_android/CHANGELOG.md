## 1.3.0

**Bug Fixes:**
- Fixed Android playlist mutations on API 33+ by using safer MediaStore playlist/member URIs.
- Fixed playlist and audio ID handling to support `Long` MediaStore IDs on newer Android versions.

## 1.2.1

**Bug Fixes:**
- Fixed issue of removing song from playlist

## 1.1.9

**Bug Fixes:**
- Fixed issue of inserting song to a playlist if it already exist

## 1.1.8

**Bug Fixes:**
- Fixed permission result not being returned from Android to Flutter

## 1.1.5

**Bug Fixes:**
- Fixed issue related to playlist renaming functionality
- Resolved permission grant issue on Android versions prior to API level 33
