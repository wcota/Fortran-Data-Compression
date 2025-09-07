program write_and_read_p
    use pipe_mod
    implicit none

    integer :: i
    type(pipe_t) :: pipe
    integer :: iostat

    ! Create a pipe to write compressed data
    ! Use `open_pipe` to immediately open the pipe
    pipe = pipe_writer("data", "gzip", overwrite=.true., open_pipe = .true.)

    ! Write data to the pipe
    do i=1,1000
        write(pipe%unit,*) i
    end do

    ! Close the pipe and report
    call pipe%close()
    call pipe%report()

    ! Create a pipe to read compressed data
    ! Use `open_pipe` to immediately open the pipe
    pipe = pipe_reader("data.gz", "gzip", open_pipe = .true.)

    ! Read data from the pipe
    do
       read(pipe%unit,*,iostat=iostat) i
       if(iostat /= 0) exit
       ! Process the read data
       write(*,*) i
    end do

    ! Close the pipe and report
    call pipe%close()
    call pipe%report()
end program write_and_read_p
