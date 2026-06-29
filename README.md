sttSav is a C++ header only region based save file library.

Used in the upcoming title [Turf2](https://turf2.net).

# Concepts
sttSav works with Dictionaries, Archives, Keys and Records.

* Archives are the files where data is saved. These are your region files. Empty regions produce no files. Archives are split into multiple files when they grow too large.
* Records are the blobs of data
* Keys describe where Records are physically in your game world. 
* Dictionaries map Keys to Archives

```
( Keys, Records ) ==> ( Dictionaries ) ==> Archives
```

Example archive hireachy:

```text
XYArchiveDictionary
ROOT
└── Region (-32768,-32768) size=65536
    │
    ├── Region (-32768,-32768) size=32768
    │   |
    │   ├── Region (-32768,-32768) size=16384
    │   │   file: region-sz16384-x-32768-y-32768.sav
    │   ├── Region (-16384,-32768) size=16384
    │   │   file: region-sz16384-x-16384-y-32768.sav
    │   ├── Region (-32768,-16384) size=16384
    │   │   file: region-sz16384-x-32768-y-16384.sav
    │   └── Region (-16384,-16384) size=16384
    │       │
    │       ├── Region (-16384,-16384) size=8192
    │       │   file: region-sz8192-x-16384-y-16384.sav
    │       ├── Region (-8192,-16384) size=8192
    │       │   file: region-sz8192-x-8192-y-16384.sav
    │       ├── Region (-16384,-8192) size=8192
    │       │   file: region-sz8192-x-16384-y-8192.sav
    │       └── Region (-8192,-8192) size=8192
    │           file: region-sz8192-x-8192-y-8192.sav
    ├── Region (0,-32768) size=32768
    │   file: region-sz32768-x0-y-32768.sav
    ├── Region (-32768,0) size=32768
    │   file: region-sz32768-x-32768-y0.sav
    └── Region (0,0) size=32768
        file: region-sz32768-x0-y0.sav
```

sttSave will only produce archive files for non-empty leaf nodes.

sttSav also provides json style binary serialisation 

* `StringEncoder`/`StringDecoder` serialises binary values and strings to or fram a string
* `BinaryWriter`/`BinaryValue` serialises binary data in a key => value JSON style format. The api has been made to be parallel to [rapidJson](https://rapidjson.org/), so you can easily write wrappers that encode JSON or sttSaveBinary records.

## Building:
This is a single header library. `#include "stt-sav.hh"`, and `#define STT_SAV_IMPL 1` in ONE compilation unit.

To modify source you need [lzz](https://github.com/SnapperTT/lzz-bin).


# Example Dictionaries

## ArchiveDictionaryI

An ArchiveDictionaryI maps application-defined archive keys to archive IDs. The dictionary is responsible for generating archive keys and determining which archive owns a particular key. It contains no file I/O logic and is independent of the archive storage format.

Different applications may implement different dictionary strategies (planetary quadtree, fixed grid, hash table, etc.).

This is the base class for all Dictionaryies

## XYArchiveDictionary
`#include planetaryFaceUVArchiveDictionary.h`

`XYArchiveDictionary` is an archive dictionary for large 2D worlds such as voxel, tile-based and open-world games. Objects are indexed using a pair of signed 16-bit coordinates `(x, y)` packed into a 32-bit key.

The world is partitioned using a quadtree. Each archive represents a square region of the world. When an archive exceeds the configured size limit, it is replaced by four child archives representing the four quadrants of that region. Conversely, small sibling archives may be merged back into their parent.

Example filename `region-sz8192-x4096-y16384.sav`.

## PlanetaryFaceUVArchiveDictionary
`#include XYArchiveDictionary.h`

`PlanetaryFaceUVArchiveDictionary` is an archive dictionary for procedurally generated planetary worlds. Objects are indexed using `(planet, face, flags, localU, localV)`, where each planet consists of six cube faces plus a global face for planet-wide data that doesn't belong to any particualar face.

Archives are partitioned hierarchically. An initial `PLANET-R` archive contains all planets. As individual planets grow, they are split into dedicated planet archives, which may then split into face archives. Face archives are recursively subdivided using a quadtree over local UV coordinates until each archive falls below the configured size limit. Small child archives may later be merged back into their parent.

Archive filenames describe the region they contain (for example `planet-3-face-2-sz32-u64-v96.sav`),

# License
Public Domain
