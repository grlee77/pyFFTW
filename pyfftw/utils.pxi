# Copyright 2012 Knowledge Economy Developments Ltd
# 
# Henry Gomersall
# heng@kedevelopments.co.uk
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

cimport numpy as np
from cpuid cimport cpuid  # a thin wrapper around cpuid assembly
from libc.stdint cimport intptr_t

cdef object _cpuid_info_and_feature_bit_masks
# tuple gives (which int, which bit)
_cpuid_info_and_feature_bit_masks = {
        'avx': (2, 28),
        'sse': (3, 25),
        'sse2': (3, 26),
        }

cdef int alignment = get_alignment()

cpdef int get_alignment():

    cpuinfo = get_cpuinfo()

    if cpuinfo['avx']:
        return 32
    elif cpuinfo['sse']:
        return 16
    else:
        return 1

cpdef get_cpuinfo():
    cdef int _cpuinfo[4]

    # function 1 is processor info and feature bits
    cpuid(1, _cpuinfo)

    cpuid_output = (_cpuinfo[0], _cpuinfo[1], _cpuinfo[2], _cpuinfo[3])

    cpuinfo = {}

    for each_mask in _cpuid_info_and_feature_bit_masks:
        int_number = _cpuid_info_and_feature_bit_masks[each_mask][0]
        bit_number = _cpuid_info_and_feature_bit_masks[each_mask][1]

        cpuinfo[each_mask] = bool(
                cpuid_output[int_number] & (1<<bit_number))

    return cpuinfo

cpdef n_byte_align_empty(shape, n, dtype='float64', order='C'):
    '''n_byte_align_empty(shape, n, dtype='float64', order='C')

    Function that returns an empty numpy array
    that is n-byte aligned.

    The alignment is given by the second argument, ``n``.
    The rest of the arguments are as per :func:`numpy.empty`.
    '''
    
    itemsize = np.dtype(dtype).itemsize

    # Apparently there is an issue with numpy.prod wrapping around on 32-bits
    # on Windows 64-bit. This shouldn't happen, but the following code 
    # alleviates the problem.
    if not isinstance(shape, int):
        array_length = 1
        for each_dimension in shape:
            array_length *= each_dimension
    
    else:
        array_length = shape

    # Allocate a new array that will contain the aligned data
    _array_aligned = np.empty(array_length*itemsize+n, dtype='int8')
    
    # We now need to know how to offset _array_aligned 
    # so it is correctly aligned
    _array_aligned_offset = (n-<intptr_t>np.PyArray_DATA(_array_aligned))%n

    array = np.frombuffer(
            _array_aligned[_array_aligned_offset:_array_aligned_offset-n].data,
            dtype=dtype).reshape(shape, order=order)
    
    return array

cpdef n_byte_align(array, n, dtype=None):
    ''' n_byte_align(array, n, dtype=None)

    Function that takes a numpy array and checks it is aligned on an n-byte
    boundary, where ``n`` is a passed parameter. If it is, the array is
    returned without further ado.  If it is not, a new array is created and
    the data copied in, but aligned on the n-byte boundary.

    ``dtype`` is an optional argument that forces the resultant array to be
    of that dtype.
    '''
    
    if not isinstance(array, np.ndarray):
        raise TypeError('Invalid array: n_byte_align requires a subclass '
                'of ndarray')

    if dtype is not None:
        if not array.dtype == dtype:
            update_dtype = True
    
    else:
        dtype = array.dtype
        update_dtype = False
    
    # See if we're already n byte aligned. If so, do nothing.
    offset = <intptr_t>np.PyArray_DATA(array) %n

    if offset is not 0 or update_dtype:

        _array_aligned = n_byte_align_empty(array.shape, n, dtype)

        _array_aligned[:] = array

        array = _array_aligned.view(type=array.__class__)
    
    return array

cpdef is_n_byte_aligned(array, n):
    ''' n_byte_align(array, n)

    Function that takes a numpy array and checks it is aligned on an n-byte
    boundary, where ``n`` is a passed parameter, returning ``True`` if it is,
    and ``False`` if it is not.
    '''
    if not isinstance(array, np.ndarray):
        raise TypeError('Invalid array: is_n_byte_aligned requires a subclass '
                'of ndarray')

    # See if we're n byte aligned.
    offset = <intptr_t>np.PyArray_DATA(array) %n

    return not bool(offset)