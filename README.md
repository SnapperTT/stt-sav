sttSav is a C++ lightweight header only region based save file library.

Used in the upcoming title [Turf2](https://turf2.net).

# Features
* File size and location based partitioning of data. No file gets too big and we don't spam lots of small files
* Crash resisistant writing. We use append only writing of records. Old records are only removed when new records have finished writing. Compaction is done on files to remove dead records and clean up metadata - new file is written and old is swapped out atomically.
* Incremental cleanup
* Both Simple and Bulk api for writing records
* Lazy loading. Files are only opened when needed.
* (optional) - binary json style encoding/decoding, using rapidjson style api. You can trivially write a json <-> stt-sav record convertor

# Concepts
sttSav works with Dictionaries, Archives, Keys and Records.

* `Archives` are the files where data is saved. These are your region files. Empty regions produce no files. Archives are split into multiple files when they grow too large.
* `Records` are the blobs of data. Every record has a `uint32_t` identifier that you use as lookup. Every record must be world unique
* `Keys` describe where `Records` are physically in your game world. 
* `Dictionaries` map Keys to Archives
* class `ArchiveManager` provides you your interface to use sttSav. Dictionaries, archive files, etc are all handled "under the hood". You just pass `(Key, Record, Blobs)` to ArchiveManager to save, and request `(Key, Record)` from it to load.

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

Archive files are written in append only to help ensure data integrity in case of crashing or power outages. Archives can be compacted which cleans out dead records.

sttSav also provides json style binary serialisation 

`#include "binaryValueWriter.h"`
* `StringEncoder`/`StringDecoder` serialises binary values and strings to or fram a string
* `BinaryWriter`/`BinaryValue` serialises binary data in a key => value JSON style format. The api has been made to be parallel to [rapidJson](https://rapidjson.org/), so you can easily write wrappers that encode JSON or sttSaveBinary records.

You don't need to use these helpers, ArchiveManager will accept any blob.

# Using
ArchiveManager is the fundamental class for stt-sav. You instantate it, assign a dictionary, set you path, and then you start adding data.

```
// Initialise new dictionary
XYArchiveDictionary Dict;
Dict.initNewDictionary();
ArchiveManager M(&Dict);
M.mBasePath = "archive-directory-name";
M.saveDictionary(); // save our initial dictionary. The dictionary will be auto-saved when it slits or merges archives

// Using
M.saveRecord(Dict.getKey(x, y), {1337}, dataOut);
M.loadRecord(Dict.getKey(x, y), {42069}, dataIn);
```

```
// Load existing dictionary
XYArchiveDictionary Dict;
ArchiveManager M(&Dict);
M.mBasePath = "archive-directory-name";
M.loadDictionary();
```

ArchiveManager also supports bulk operations to minimize disc i/o:

```
std::string stringOut;
sttSav::transaction t[3];
t[0] = sttSav::transaction::makeLoad(key, record, stringOut);
t[1] = sttSav::transaction::makeSave(key2, record2, dataIn.data(), dataIn.size());
t[2] = sttSav::transaction::deleteRecord(key3, record3);

M.doTransactions(&t, 3);
```

You can even batch bulk operations:
```
sttSave::transaction t[32];
uint32_t nTransations;
M.startBulkTransations(); // keep files open while working on them
while (nTransations = queue.read(t, nTransations, 32)) {
	M.doTransactions(&t, nTransactions);
	}
M.endBulkTransations(); // closes any open files
```

# Maintenance

Archives are writen in append only. This is to make the archive files resistant against crashes or power outages.

Archive files should also be split if they get too big and merged if they are too small.

You *must* call the function `doMaintenance` periodocially. 

This function performs maintenance on the ArchiveFiles
- splits oversized ArchiveFiles
- merges undersized groups of ArchiveFiles
- compacts (removes dead entries) from ArchiveFiles

```
doMaintenance(const bool incremental, const bool aggressive);

//incremental = true  => return after writing one file
//              false => scan all ArchiveFiles, and 
//aggressive  = true  => compact any files that have *any* wasted bytes
//              false => scan all ArchiveFiles, and compact only files with
//                       compactionRatio < (wastedSpace+usedSpace)/usedSpace
```

ArchiveManager has the following parameters you can tweak:

```
class ArchiveManager {
...
	float compactionRatio; // (unused space + used space)/(used space) > this? Compact!
	uint32_t maxArchiveSize; // bigger than this? split!
	uint32_t minimumArchiveSize; // all archives smaller than this? 
```

Default values are 1.5, 8MB and 1MB respectively.


# Building
This is a single header library. `#include "stt-sav.hh"`, and `#define STT_SAV_IMPL 1` in ONE compilation unit.

To modify source you need [lzz](https://github.com/SnapperTT/lzz-bin).


# Example Dictionaries

## ArchiveDictionaryI

An ArchiveDictionaryI maps application-defined archive keys to archive IDs. The dictionary is responsible for generating archive keys and determining which archive owns a particular key. It contains no file I/O logic and is independent of the archive storage format.

Different applications may implement different dictionary strategies (planetary quadtree, fixed grid, hash table, etc.).

This is the base class for all Dictionaries

## XYArchiveDictionary
`#include XYArchiveDictionary.h`

`XYArchiveDictionary` is an archive dictionary for large 2D worlds such as voxel, tile-based and open-world games. Objects are indexed using a pair of signed 16-bit coordinates `(x, y)` packed into a 32-bit key.

The world is partitioned using a quadtree. Each archive represents a square region of the world. When an archive exceeds the configured size limit, it is replaced by four child archives representing the four quadrants of that region. Conversely, small sibling archives may be merged back into their parent.

Example filename `region-sz8192-x4096-y16384.sav`.

## PlanetaryFaceUVArchiveDictionary
`#include planetaryFaceUVArchiveDictionary.h`

`PlanetaryFaceUVArchiveDictionary` is an archive dictionary for procedurally generated planetary worlds. Objects are indexed using `(planet, face, flags, localU, localV)`, where each planet consists of six cube faces plus a global face for planet-wide data that doesn't belong to any particualar face.

Archives are partitioned hierarchically. An initial `PLANET-R` archive contains all planets. As individual planets grow, they are split into dedicated planet archives, which may then split into face archives. Face archives are recursively subdivided using a quadtree over local UV coordinates until each archive falls below the configured size limit. Small child archives may later be merged back into their parent.

Archive filenames describe the region they contain (for example `planet-3-face-2-sz32-u64-v96.sav`),

# License
Public Domain
