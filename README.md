# Fortran Data Compression ([FPM package](https://fpm.fortran-lang.org/))

Sample programs demonstrating the ability to compress/decompress data on the fly
when writing to or reading from a file in Fortran using named pipes (FIFOs).

This project has been modernized to use the [Fortran Package Manager (FPM)]((https://fpm.fortran-lang.org/)), simplifying compilation, dependency management, and code reuse.

## Module `pipe_mod`

The core compression/decompression functionality is now encapsulated in a modern Fortran module, `pipe_mod`.

It provides a derived type `pipe_t` and its constructors `pipe_writer` and `pipe_reader`, which handle:

- FIFO creation and removal
- Opening and closing
- Execution of compression/decompression commands

## Usage

First, import the module `pipe_mod`.

### Writing data

To write a file, use the constructor `pipe_writer` as follows:

```fortran
use pipe_mod
...
type(pipe_t) :: pipe
...
pipe = pipe_writer("filename", "gzip", overwrite=.true., open_pipe = .true.)
```

- Use `overwrite` to allow overwriting an existing file.
- The filename must not include the extension.
- Supported compressors (Linux): `pigz`, `gzip`, `lz4c`, `lzop`.

To write data, use `pipe%unit` as file unit and write as usual. For example,

```fortran
write(pipe%unit,*) "Any text", variable, "and so on"
```

After writing, close the pipe with:

```fortran
call pipe%close()
```

You can also check the final file size using:

```fortran
pipe%report()
```

### Reading data

The process is similar, but use `pipe_reader`:

```fortran
use pipe_mod
...
type(pipe_t) :: pipe
...
pipe = pipe_reader("filename.gz", "gzip", open_pipe = .true.)
```

- Here, the filename must include the extension.

Use `pipe%unit` as fileunit to read:

```fortran
do
    read(pipe%unit,*,iostat=iostat) i
    if(iostat /= 0) exit
    ! Process the read data
    write(*,*) i
end do
```

See [write_and_read.f90](./example/write_and_read.f90) for more examples.

## Usage with FPM

To add this project as a dependency, include in your `fpm.toml`:

```toml
[dependencies]
Fortran-Data-Compression.git = "https://github.com/wcota/Fortran-Data-Compression"
```

To run the example, use

```sh
fpm run --example
```

## Compilation (original version)

The original version is at [test](./test) folder or in its original repository [SokolAK/Fortran-Data-Compression](https://github.com/SokolAK/Fortran-Data-Compression).

* Set your compiler in `Makefile` (`ifort`, `gfortran` or `f77`)
* Run `make`

## Usage (original version)

### Writing to file

Run: `./write <N> [F] [L]`<br>
where:<br>
`N` - number of lines to write to the file [required]<br>
`F` - compression filter (`gzip`, `pigz`, `lz4c`, `lzop`) [optional]<br>
`L` - compression level (from `-1` to `-9`) [optional]<br>

Data will be written to the `data.*` file.
If no compression filter is specified, data will not be compressed.

### Reading from file

Run `./read [F]`<br>
where:<br>
`F` - compression filter (use the same as for writing) [optional]<br>

## Additional information

This project is adapted from the original work by [Adam K. Sokół](https://github.com/SokolAK), based on the repository [SokolAK/Fortran-Data-Compression](https://github.com/SokolAK/Fortran-Data-Compression).
