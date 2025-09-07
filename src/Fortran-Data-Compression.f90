module pipe_mod
    !> Based on https://github.com/SokolAK/Fortran-Data-Compression
    use iso_fortran_env, only: i4 => int32
    implicit none
    private

    type :: pipe_t
        character(len=:), allocatable :: compressor
        character(len=:), allocatable :: filename
        character(len=:), allocatable :: instruction
        character(len=:), allocatable :: fifo_path
        character(len=:), allocatable :: level
        integer(kind=i4) :: unit = -1
    contains
        procedure :: start => start_pipe
        procedure :: open => open_pipe
        procedure :: close => close_pipe
        procedure :: report => report_size
    end type pipe_t

    public :: pipe_writer
    public :: pipe_reader
    public :: pipe_t

contains

!> Function to create and configure a pipe reader
!> It will create a FIFO and prepare the command to read and decompress data through it
    function pipe_reader(filename, compressor, open_pipe) result(pr)
        character(len=*), intent(in) :: filename
        character(len=*), intent(in) :: compressor
        logical, intent(in), optional :: open_pipe
        type(pipe_t) :: pr
        character(len=:), allocatable :: basefile

        ! Remove any trailing spaces and store
        pr%compressor = trim(adjustl(compressor))
        pr%filename = trim(adjustl(filename))

        ! Safety: check if filename does not contain any wildcard characters
        if (.not. filename_exists(pr%filename)) then
            error stop "Filename does not exist."
        end if

        ! Define FIFO path (same name as filename plus ".fifo")
        basefile = trim(adjustl(filename))
        pr%fifo_path = basefile // ".fifo"

        ! Build the instruction based on compressor
        select case (pr%compressor)
          case('pigz')
            pr%instruction = "| " // pr%compressor // " -dc"
          case('gzip')
            pr%instruction = "| " // pr%compressor // " -dc"
          case('lz4c')
            pr%instruction = "| " // pr%compressor // " -dc"
          case('lzop')
            pr%instruction = "| " // pr%compressor // " -dc"
          case default
            pr%instruction = ""
        end select

        pr%instruction = "( cat '" // basefile // "' " // pr%instruction // " > '" // pr%fifo_path  // "'; echo \x4 > '" // pr%fifo_path // "' ) &"

        if (present(open_pipe)) then
            if (open_pipe) then
                call pr%start()
                call pr%open()
            end if
        end if

    end function pipe_reader

    !> Function to create and configure a pipe writer
    !> It will create a FIFO and prepare the command to write data through it
    function pipe_writer(filename, compressor, level, overwrite, open_pipe) result(pw)
        character(len=*), intent(in) :: compressor
        integer(kind=i4), intent(in), optional :: level
        character(len=*), intent(in) :: filename
        logical, intent(in), optional :: overwrite
        logical, intent(in), optional :: open_pipe
        character(len=:), allocatable :: ext_str
        type(pipe_t) :: pw
        character(len=256) :: level_str

        if (present(level)) then
            write(level, '(I2)') level_str
            level_str = " -" // trim(adjustl(level_str))
        else
            level_str = ""
        end if

        pw%compressor = trim(adjustl(compressor))
        pw%level = trim(adjustl(level_str))

        ! Choose output filename based on compressor
        select case (pw%compressor)
          case('pigz', 'gzip')
            ext_str = ".gz"
          case('lz4c')
            ext_str = ".lz4"
          case('lzop')
            ext_str = ".lzo"
          case default
            ext_str = ""
        end select

        pw%filename = trim(adjustl(filename)) // ext_str

        ! Safety: check if filename does not contain any wildcard characters
        if (.not. is_valid_filename(pw%filename, overwrite=overwrite)) then
            error stop "Invalid filename or file already exists. Use overwrite option to replace."
        end if

        ! Create a FIFO path
        pw%fifo_path = pw%filename // ".fifo"

        if (pw%compressor == 'none') then
            pw%instruction = "cat '" // pw%fifo_path // "'"
        else
            pw%instruction = "cat '" // pw%fifo_path // "' | " // pw%compressor // level_str
        end if
        pw%instruction = trim(pw%instruction) // " > " // trim(pw%filename) // " &"

        if (present(open_pipe)) then
            if (open_pipe) then
                call pw%start()
                call pw%open()
            end if
        end if

    end function pipe_writer

    !> Start the pipe by creating the FIFO and executing the command
    subroutine start_pipe(this)
        class(pipe_t), intent(inout) :: this
        integer(kind=i4) :: system_status
        call execute_command_line("rm -f '" // this%fifo_path // "'; mkfifo '" // this%fifo_path // "'", exitstat=system_status)
        if (system_status /= 0) then
            error stop "Error creating FIFO"
        end if
        call execute_command_line(this%instruction, exitstat=system_status)
        if (system_status /= 0) then
            error stop "Error starting compression command"
        end if
    end subroutine start_pipe

    !> Open the FIFO
    subroutine open_pipe(this)
        class(pipe_t), intent(inout) :: this
        integer(kind=i4) :: ios
        open(newunit=this%unit, file=trim(this%fifo_path), iostat=ios)
        if (ios /= 0) then
            error stop "Error opening FIFO"
        end if
    end subroutine open_pipe

    !> Close the FIFO and remove it
    subroutine close_pipe(this)
        class(pipe_t), intent(inout) :: this
        integer(kind=i4) :: system_status

        call execute_command_line("rm -f '" // this%fifo_path // "'", exitstat=system_status)

        if (system_status /= 0) then
            error stop "Error removing FIFO"
        end if

        if (this%unit /= -1) then
            close(this%unit)
        end if

        this%unit = -1
    end subroutine close_pipe

    !> Report the size of the created archive
    subroutine report_size(this)
        class(pipe_t), intent(in) :: this
        character(len=512) :: cmd
        integer(kind=i4) :: system_status
        cmd = "echo -n 'Archive size: '; ls -lh '" // trim(this%filename) // "' | awk '{print $5}'"
        call execute_command_line(cmd, exitstat=system_status)
        if (system_status /= 0) then
            error stop "Error reporting file size"
        end if
    end subroutine report_size

    !> Check if a filename is valid (no wildcards, does not exist)
    !> TODO: Check if it is a directory before writing
    logical function is_valid_filename(fname, overwrite)
        character(len=*), intent(in) :: fname
        logical, intent(in), optional :: overwrite
        logical :: overwrite_local, exists
        integer(kind=i4) :: i
        character(len=*), parameter :: invalid_chars = '*?"<>|'

        if (present(overwrite)) then
            overwrite_local = overwrite
        else
            overwrite_local = .false.
        end if

        ! check if empty
        if (len_trim(fname) == 0) then
            is_valid_filename = .false.
            return
        end if

        ! check if there are invalid characters
        do i = 1, len_trim(fname)
            if (index(invalid_chars, fname(i:i)) /= 0) then
                is_valid_filename = .false.
                return
            end if
        end do

        ! Check if file exists
        inquire(file=trim(fname), exist=exists)

        if (exists .and. .not. overwrite_local) then
            is_valid_filename = .false.
            return
        end if

        ! Check if it is a directory
        call execute_command_line("test -d '" // trim(fname) // "'", exitstat=i)
        if (i == 0) then
            is_valid_filename = .false.
            return
        end if

        ! Passed all checks
        is_valid_filename = .true.
    end function is_valid_filename

    !> Check if file exists
    logical function filename_exists(fname)
        character(len=*), intent(in) :: fname
        logical :: exists
        inquire(file=trim(fname), exist=exists)
        filename_exists = exists
    end function filename_exists

end module pipe_mod
