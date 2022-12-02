## Basic Naming

 - cache file: the file storing serialized spec. with `.deps` file extension name.
 - spec source file: the file containing bundle spec
 - code source file: the file containing the codes to be bundle.
 - spec: a definition of a bundle name, how it should be built, and who defines it.


## spec

Spec is the metadata for how to bundle files into a bundle. It can be represented by a JSON with following fields, or by a `spec` object constructed with this JSON as options:

 - `type`: bundle file type of this spec. either `js`, `css` or `block`
 - `name`: file name, including path. no extension. e.g., `abc/def`
 - `codesrc`: Array (in JSON) / Set (in Object) of names of files to be bundled.
 - `specsrc`: Array (in JSON) / Set (in Object) of names of files deciding this spec.

Constructed `spec` object has following API methods:

 - `toObject()`
 - `cacheFn()`: corresponding cache file
 - 


## cache files

Dep files are the cache file storing a serialized spec object. It's name, with `.deps` as file extension, directly corresponds to a specific bundle file, with lists of depended code source files and the source files generating this spec.

Instead of calculating bundling rules from source files, cache files establish inversed link from bundles to `codesrc` and `specsrc`, which helps to keep track of how to build a bundle file and whether we should still build this file.

Dep files are auto generated and thus can be removed at any time. However, a complete source file scanning will be needed if we want to reconstruct the cache files and make sure all bundles are up to date.

A cache file stores simply the serialized result of a spec:

    spec.sync-file! # equivalent to following line
    fs.write-file-sync(spec.cache-fn!, spec.to-object!) # where the written object is the same with
    this-object = new spec( JSON.stringify(fs.read-file-sync(spec.cache-fn!)) )


default config (both in constructor option and content of config-file)

  {
    css: {name: [files, ...], ...},
    js: {name: [files, ...], ...},
    block: {name: [files, ...], ...}
  }


## auto bundling

use compile time filter:

    :bundle(options = { ... })

where options is an object, or an array of objects with following fields:

 - `type`: resource type. either `js`, `css` or `block`
   - corresponding tag will be generated based on `type`:
     - `js`: `script`
     - `css`: `link` or `style`
     - `block`: `template` or `link` (TBD)
 - `embed`: default false. embed the bundled content or not. (TODO)
 - `sort`: sort list or not. default true for block type, and ignored for js / css type.
 - `list`: an array of bids.

block bundling requires manager be provided. this can also be used for runtime library loading for converting bid to path. (TODO)
