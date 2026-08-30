subroutine BOM_SHA256_FILE(path, digest, ierr)
  use, intrinsic :: iso_fortran_env, only : int8, int64
  implicit none
  character(len=*), intent(in) :: path
  character(len=64), intent(out) :: digest
  integer, intent(out) :: ierr

  integer(int64), parameter :: mask32 = int(z'FFFFFFFF', int64)
  integer(int64), parameter :: k256(64) = [ &
       int(z'428A2F98',int64), int(z'71374491',int64), &
       int(z'B5C0FBCF',int64), int(z'E9B5DBA5',int64), &
       int(z'3956C25B',int64), int(z'59F111F1',int64), &
       int(z'923F82A4',int64), int(z'AB1C5ED5',int64), &
       int(z'D807AA98',int64), int(z'12835B01',int64), &
       int(z'243185BE',int64), int(z'550C7DC3',int64), &
       int(z'72BE5D74',int64), int(z'80DEB1FE',int64), &
       int(z'9BDC06A7',int64), int(z'C19BF174',int64), &
       int(z'E49B69C1',int64), int(z'EFBE4786',int64), &
       int(z'0FC19DC6',int64), int(z'240CA1CC',int64), &
       int(z'2DE92C6F',int64), int(z'4A7484AA',int64), &
       int(z'5CB0A9DC',int64), int(z'76F988DA',int64), &
       int(z'983E5152',int64), int(z'A831C66D',int64), &
       int(z'B00327C8',int64), int(z'BF597FC7',int64), &
       int(z'C6E00BF3',int64), int(z'D5A79147',int64), &
       int(z'06CA6351',int64), int(z'14292967',int64), &
       int(z'27B70A85',int64), int(z'2E1B2138',int64), &
       int(z'4D2C6DFC',int64), int(z'53380D13',int64), &
       int(z'650A7354',int64), int(z'766A0ABB',int64), &
       int(z'81C2C92E',int64), int(z'92722C85',int64), &
       int(z'A2BFE8A1',int64), int(z'A81A664B',int64), &
       int(z'C24B8B70',int64), int(z'C76C51A3',int64), &
       int(z'D192E819',int64), int(z'D6990624',int64), &
       int(z'F40E3585',int64), int(z'106AA070',int64), &
       int(z'19A4C116',int64), int(z'1E376C08',int64), &
       int(z'2748774C',int64), int(z'34B0BCB5',int64), &
       int(z'391C0CB3',int64), int(z'4ED8AA4A',int64), &
       int(z'5B9CCA4F',int64), int(z'682E6FF3',int64), &
       int(z'748F82EE',int64), int(z'78A5636F',int64), &
       int(z'84C87814',int64), int(z'8CC70208',int64), &
       int(z'90BEFFFA',int64), int(z'A4506CEB',int64), &
       int(z'BEF9A3F7',int64), int(z'C67178F2',int64) ]
  integer(int64) :: h(8), w(64)
  integer(int64) :: a,b,c,d,e,f,g,hh,t1,t2
  integer(int64) :: file_size, bit_length, nblocks
  integer(int64) :: block_index, absolute_pos, byte_value
  integer(int8) :: byte_read
  integer :: unit_number, ios, i, j
  character(len=8) :: word_hex

  digest = repeat('0',64)
  ierr = 0
  inquire(file=trim(path), size=file_size, iostat=ios)
  if (ios /= 0 .or. file_size < 0_int64) then
    ierr = 1
    return
  end if
  open(newunit=unit_number, file=trim(path), status='old', &
       access='stream', form='unformatted', action='read', iostat=ios)
  if (ios /= 0) then
    ierr = 2
    return
  end if

  h = [ int(z'6A09E667',int64), int(z'BB67AE85',int64), &
        int(z'3C6EF372',int64), int(z'A54FF53A',int64), &
        int(z'510E527F',int64), int(z'9B05688C',int64), &
        int(z'1F83D9AB',int64), int(z'5BE0CD19',int64) ]
  bit_length = file_size*8_int64
  nblocks = (file_size+9_int64+63_int64)/64_int64

  do block_index=0_int64,nblocks-1_int64
    do i=1,16
      w(i)=0_int64
      do j=1,4
        absolute_pos=block_index*64_int64+int(4*(i-1)+j,int64)
        if (absolute_pos <= file_size) then
          read(unit_number,pos=absolute_pos,iostat=ios) byte_read
          if (ios /= 0) then
            close(unit_number)
            ierr=3
            return
          end if
          byte_value=iand(int(byte_read,int64),255_int64)
        else if (absolute_pos == file_size+1_int64) then
          byte_value=128_int64
        else if (absolute_pos > nblocks*64_int64-8_int64) then
          byte_value=iand(shiftr(bit_length, &
               int((nblocks*64_int64-absolute_pos)*8_int64)),255_int64)
        else
          byte_value=0_int64
        end if
        w(i)=ior(shiftl(w(i),8),byte_value)
      end do
    end do
    do i=17,64
      w(i)=iand(w(i-16)+small_sigma0(w(i-15)) &
           +w(i-7)+small_sigma1(w(i-2)),mask32)
    end do

    a=h(1); b=h(2); c=h(3); d=h(4)
    e=h(5); f=h(6); g=h(7); hh=h(8)
    do i=1,64
      t1=iand(hh+big_sigma1(e)+choose_word(e,f,g)+k256(i)+w(i), &
           mask32)
      t2=iand(big_sigma0(a)+majority_word(a,b,c),mask32)
      hh=g; g=f; f=e
      e=iand(d+t1,mask32)
      d=c; c=b; b=a
      a=iand(t1+t2,mask32)
    end do
    h(1)=iand(h(1)+a,mask32)
    h(2)=iand(h(2)+b,mask32)
    h(3)=iand(h(3)+c,mask32)
    h(4)=iand(h(4)+d,mask32)
    h(5)=iand(h(5)+e,mask32)
    h(6)=iand(h(6)+f,mask32)
    h(7)=iand(h(7)+g,mask32)
    h(8)=iand(h(8)+hh,mask32)
  end do
  close(unit_number)

  do i=1,8
    write(word_hex,'(Z8.8)') h(i)
    call lowercase_hex(word_hex)
    digest(8*(i-1)+1:8*i)=word_hex
  end do

contains

  pure integer(int64) function rotate_right32(x,n)
    integer(int64), intent(in) :: x
    integer, intent(in) :: n
    rotate_right32=ior(shiftr(iand(x,mask32),n), &
         iand(shiftl(iand(x,mask32),32-n),mask32))
  end function rotate_right32

  pure integer(int64) function small_sigma0(x)
    integer(int64), intent(in) :: x
    small_sigma0=ieor(ieor(rotate_right32(x,7), &
         rotate_right32(x,18)),shiftr(x,3))
  end function small_sigma0

  pure integer(int64) function small_sigma1(x)
    integer(int64), intent(in) :: x
    small_sigma1=ieor(ieor(rotate_right32(x,17), &
         rotate_right32(x,19)),shiftr(x,10))
  end function small_sigma1

  pure integer(int64) function big_sigma0(x)
    integer(int64), intent(in) :: x
    big_sigma0=ieor(ieor(rotate_right32(x,2), &
         rotate_right32(x,13)),rotate_right32(x,22))
  end function big_sigma0

  pure integer(int64) function big_sigma1(x)
    integer(int64), intent(in) :: x
    big_sigma1=ieor(ieor(rotate_right32(x,6), &
         rotate_right32(x,11)),rotate_right32(x,25))
  end function big_sigma1

  pure integer(int64) function choose_word(x,y,z)
    integer(int64), intent(in) :: x,y,z
    choose_word=ieor(iand(x,y),iand(ieor(x,mask32),z))
  end function choose_word

  pure integer(int64) function majority_word(x,y,z)
    integer(int64), intent(in) :: x,y,z
    majority_word=ieor(ieor(iand(x,y),iand(x,z)),iand(y,z))
  end function majority_word

  subroutine lowercase_hex(value)
    character(len=*), intent(inout) :: value
    integer :: n, code
    do n=1,len(value)
      code=iachar(value(n:n))
      if (code >= iachar('A') .and. code <= iachar('F')) &
           value(n:n)=achar(code+iachar('a')-iachar('A'))
    end do
  end subroutine lowercase_hex

end subroutine BOM_SHA256_FILE

subroutine BOM_COPY_FILE_BYTES(source_path, destination_path, &
     source_required, ierr)
  use, intrinsic :: iso_fortran_env, only : int8, int64
  implicit none
  character(len=*), intent(in) :: source_path, destination_path
  logical, intent(in) :: source_required
  integer, intent(out) :: ierr
  integer(int8) :: buffer(65536)
  integer(int64) :: file_size, position, remaining
  integer :: source_unit, destination_unit, ios, chunk_size
  logical :: source_exists

  ierr=0
  inquire(file=trim(source_path),exist=source_exists,size=file_size, &
       iostat=ios)
  if (ios /= 0 .or. (source_required .and. .not.source_exists)) then
    ierr=1
    return
  end if
  open(newunit=destination_unit,file=trim(destination_path), &
       status='replace',access='stream',form='unformatted', &
       action='write',iostat=ios)
  if (ios /= 0) then
    ierr=2
    return
  end if
  if (.not.source_exists) then
    close(destination_unit,iostat=ios)
    if (ios /= 0) ierr=3
    return
  end if
  open(newunit=source_unit,file=trim(source_path),status='old', &
       access='stream',form='unformatted',action='read',iostat=ios)
  if (ios /= 0) then
    close(destination_unit)
    ierr=4
    return
  end if
  position=1_int64
  remaining=file_size
  do while (remaining > 0_int64)
    chunk_size=int(min(remaining,int(size(buffer),int64)))
    read(source_unit,pos=position,iostat=ios) buffer(1:chunk_size)
    if (ios /= 0) exit
    write(destination_unit,iostat=ios) buffer(1:chunk_size)
    if (ios /= 0) exit
    position=position+int(chunk_size,int64)
    remaining=remaining-int(chunk_size,int64)
  end do
  close(source_unit)
  close(destination_unit)
  if (ios /= 0) ierr=5
end subroutine BOM_COPY_FILE_BYTES
