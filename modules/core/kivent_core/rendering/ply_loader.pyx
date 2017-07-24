import sys

from libc.stdint cimport (int8_t, int16_t, int32_t, uint8_t, uint16_t, uint32_t,
    INT8_MIN, INT8_MAX, INT16_MIN, INT16_MAX, INT32_MIN, INT32_MAX, UINT8_MAX,
    UINT16_MAX, UINT32_MAX)
from libc.stdlib cimport malloc, realloc, free, strtol, strtoul, strtof, strtod
from libc.stdio cimport (FILE, fopen, fclose, ftell, fgets, feof, fread, fseek,
    SEEK_END, SEEK_SET, printf)
from libc.string cimport strcmp, strcat, strlen, strtok, strcpy, memcpy
from libc.errno cimport errno, ERANGE

from vertex_formats cimport FormatConfig, format_registrar

cdef char* MAGIC_NUMBER = 'ply'
cdef char* KW_FORMAT = 'format'
cdef char* KW_COMMENT = 'comment'
cdef char* KW_ELEMENT = 'element'
cdef char* KW_PROPERTY = 'property'
cdef char* KW_LIST = 'list'
cdef char* END_HEADER = 'end_header'
cdef char* FMT_ASCII = 'ascii'
cdef char* FMT_BIN_LE = 'binary_little_endian'
cdef char* FMT_BIN_BE = 'binary_big_endian'
cdef char* VERSION = '1.0'
cdef char* TYPE_CHAR = 'char'
cdef char* TYPE_UCHAR = 'uchar'
cdef char* TYPE_SHORT = 'short'
cdef char* TYPE_USHORT = 'ushort'
cdef char* TYPE_INT = 'int'
cdef char* TYPE_UINT = 'uint'
cdef char* TYPE_FLOAT = 'float'
cdef char* TYPE_DOUBLE = 'double'
# The following are non-standard type keywords used by some tools.
cdef char* TYPE_INT8 = 'int8'
cdef char* TYPE_UINT8 = 'uint8'
cdef char* TYPE_INT16 = 'int16'
cdef char* TYPE_UINT16 = 'uint16'
cdef char* TYPE_INT32 = 'int32'
cdef char* TYPE_UINT32 = 'uint32'
cdef char* TYPE_FLOAT32 = 'float32'
cdef char* TYPE_FLOAT64 = 'float64'
cdef char* DELIMETERS = ' \r\n'
cdef size_t SIZE_INT8 = sizeof(int8_t)
cdef size_t SIZE_UINT8 = sizeof(uint8_t)
cdef size_t SIZE_INT16 = sizeof(int16_t)
cdef size_t SIZE_UINT16 = sizeof(uint16_t)
cdef size_t SIZE_INT32 = sizeof(int32_t)
cdef size_t SIZE_UINT32 = sizeof(uint32_t)
cdef size_t SIZE_FLOAT = sizeof(float)
cdef size_t SIZE_DOUBLE = sizeof(double)

cdef size_t BUF_SIZE = 256
cdef char NO_TYPE = '\0'
cdef char* SYS_ENDIAN = FMT_BIN_LE if sys.byteorder == 'little' else FMT_BIN_BE

cdef class PLY:
    def __cinit__(self, bytes filename):
        self.filename = filename
        self.format = NULL
        self.is_ascii = 1
        self.is_same_endian = 1
        self.version = NULL
        self.num_elements = 0
        self.elements = NULL
        self._is_loaded = self.load(filename)
        self.vertex_format_name = 'vertex_format_3d_5f'

        self.elem_name_indices = 'face'
        self.prop_name_indices = 'vertex_indices'
        self.elem_name_vertices = 'vertex'

    property is_loaded:
        def __get__(self):
            return self._is_loaded

    property vertex_format:
        def __get__(self):
            return self.vertex_format_name
        def __set__(self, bytes format_name):
            self.vertex_format_name = format_name

    property indices:
        def __get__(self):
            cdef list indices = []
            cdef PLYElement* elem = NULL
            cdef PLYProp* prop = NULL
            cdef long prop_count = 0
            cdef char char_type
            cdef long index = 0
            cdef long i, j

            elem = self.get_element_by_name(self.elem_name_indices)
            if elem != NULL:
                prop = PLY.get_property_by_name(elem, self.prop_name_indices)
            if prop != NULL and PLY.property_is_list(prop):
                for i in range(elem.count):
                    char_type = prop.type
                    prop_count = prop.count[i]
                    if prop_count == 3:
                        for j in range(prop_count):
                            if char_type == 'c':
                                index = (<int8_t**>prop.data_list)[i][j]
                            elif char_type == 'C':
                                index = (<uint8_t**>prop.data_list)[i][j]
                            elif char_type == 's':
                                index = (<int16_t**>prop.data_list)[i][j]
                            elif char_type == 'S':
                                index = (<uint16_t**>prop.data_list)[i][j]
                            elif char_type == 'i':
                                index = (<int32_t**>prop.data_list)[i][j]
                            elif char_type == 'I':
                                index = (<uint32_t**>prop.data_list)[i][j]
                            else:
                                continue
                            indices.append(index)
            return indices

    property vertices:
        def __get__(self):
            cdef dict vertices = {}
            cdef dict prop_dict = vertex_format_prop_map.ply_properties[
                self.vertex_format_name]
            cdef bytes attr_name, prop_name
            cdef tuple prop_names
            cdef list attr_vals
            cdef char char_type
            cdef long i

            elem = self.get_element_by_name(self.elem_name_vertices)
            if elem != NULL:
                vertices = dict(
                    (i, dict( (k, []) for k in prop_dict.keys() )) for i in range(elem.count)
                    )
                for attr_name, prop_names in prop_dict.items():
                    for prop_name in prop_names:
                        prop = PLY.get_property_by_name(elem, prop_name)
                        if prop != NULL and PLY.property_is_list(prop) != 1:
                            char_type = prop.type
                            for i in range(elem.count):
                                attr_vals = vertices[i][attr_name]
                                if char_type == 'c':
                                    attr_vals.append((<int8_t*>prop.data)[i])
                                elif char_type == 'C':
                                    attr_vals.append((<uint8_t*>prop.data)[i])
                                elif char_type == 's':
                                    attr_vals.append((<int16_t*>prop.data)[i])
                                elif char_type == 'S':
                                    attr_vals.append((<uint16_t*>prop.data)[i])
                                elif char_type == 'i':
                                    attr_vals.append((<int32_t*>prop.data)[i])
                                elif char_type == 'I':
                                    attr_vals.append((<uint32_t*>prop.data)[i])
                                elif char_type == 'f':
                                    attr_vals.append((<float*>prop.data)[i])
                                elif char_type == 'd':
                                    attr_vals.append((<double*>prop.data)[i])
                                else:
                                    continue
            return vertices

    cdef int load(self, char* filename) nogil:
        cdef FILE* fp
        fp = fopen(filename, 'rb')
        if fp == NULL:
            return 0

        cdef char* buffer = <char*>malloc(sizeof(char) * BUF_SIZE)
        cdef int is_ply = 0
        cdef int header_read = 0
        cdef int body_read = 0

        is_ply = self.check_magic_number(fp, &buffer, BUF_SIZE)
        if is_ply == 1:
            header_read = self.read_parse_header(fp, &buffer, BUF_SIZE)
        if header_read == 1:
            if self.is_ascii:
                buffer = <char*>realloc(buffer, sizeof(char) * BUF_SIZE)
                body_read = self.read_parse_body_ascii(fp, &buffer, BUF_SIZE)
            else:
                body_read = self.read_parse_body_binary(fp, &buffer)

        fclose(fp)
        free(buffer)

        if body_read == 1:
            return 1
        return 0

    cdef int check_magic_number(self, FILE* fp, char** ptr_to_buf, size_t buf_size) nogil:
        cdef char* buffer = ptr_to_buf[0]

        fgets(buffer, 4, fp)
        token = strtok(buffer, DELIMETERS)
        if token == NULL or strcmp(token, MAGIC_NUMBER) != 0:
            return 0
        return 1

    cdef int read_parse_header(self, FILE* fp, char** ptr_to_buf, size_t buf_size) nogil:
        cdef size_t num_get = buf_size
        cdef char* buffer = ptr_to_buf[0]
        cdef char* buf_ptr = buffer
        cdef char* token = NULL
        cdef long pos = 0
        cdef long last_pos = 0
        cdef long bytes_read = 0
        cdef long buf_len = 0
        cdef long i, j, k, m
        cdef long long_count
        cdef PLYElement* elem
        cdef PLYProp* prop
        cdef size_t type_size

        pos = ftell(fp)
        while fgets(buf_ptr, num_get, fp):
            last_pos = pos
            pos = ftell(fp)
            bytes_read = pos - last_pos
            buf_len += bytes_read
            if buf_ptr[bytes_read-1] == '\r' or buf_ptr[bytes_read-1] == '\n':
                token = strtok(buffer, DELIMETERS)
                if token == NULL:
                    pass
                elif strcmp(token, KW_PROPERTY) == 0:
                    if self.num_elements <= 0:
                        return 0
                    i = self.num_elements-1
                    elem = &self.elements[i]
                    token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    elem.num_props += 1
                    if elem.num_props == 1:
                        elem.props = <PLYProp*>malloc(sizeof(PLYProp))
                    else:
                        elem.props = <PLYProp*>realloc(elem.props,
                            sizeof(PLYProp) * elem.num_props)
                    j = elem.num_props-1
                    prop = &elem.props[j]
                    if strcmp(token, KW_LIST) == 0:
                        token = strtok(NULL, DELIMETERS)
                        if token == NULL:
                            return 0
                        prop.count_type = PLY.map_type(token)
                        if prop.count_type == NO_TYPE:
                            return 0
                        token = strtok(NULL, DELIMETERS)
                        if token == NULL:
                            return 0
                    else:
                        prop.count_type = NO_TYPE
                    prop.type = PLY.map_type(token)
                    if prop.type == NO_TYPE:
                        return 0
                    token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    prop.name = <char*>malloc(strlen(token)+1)
                    strcpy(prop.name, token)
                    if prop.count_type == NO_TYPE:
                        type_size = PLY.size_of_type(prop.type)
                        if type_size == 0:
                            return 0
                        prop.data = malloc(type_size * elem.count)
                        prop.count = NULL
                        prop.data_list = NULL
                    else:
                        prop.count = <long*>malloc(sizeof(long) * elem.count)
                        prop.data_list = <void**>malloc(sizeof(void*) * elem.count)
                        prop.data = NULL
                elif strcmp(token, KW_ELEMENT) == 0:
                    self.num_elements += 1
                    if self.num_elements == 1:
                        self.elements = <PLYElement*>malloc(sizeof(PLYElement))
                    else:
                        self.elements = <PLYElement*>realloc(self.elements,
                            sizeof(PLYElement) * self.num_elements)
                    i = self.num_elements-1
                    elem = &self.elements[i]
                    elem.num_props = 0
                    token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    elem.name = <char*>malloc(strlen(token)+1)
                    strcpy(elem.name, token)
                    token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    elem.count = strtol(token, NULL, 10)
                elif strcmp(token, KW_COMMENT) == 0:
                    pass
                elif strcmp(token, KW_FORMAT) == 0:
                    token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    if strcmp(token, FMT_ASCII) == 0:
                        self.is_ascii = 1
                    elif strcmp(token, FMT_BIN_LE) == 0 or strcmp(token, FMT_BIN_BE) == 0:
                        self.is_ascii = 0
                    else:
                        return 0
                    self.format = <char*>malloc(strlen(token)+1)
                    strcpy(self.format, token)
                    if self.is_ascii == 0:
                        if strcmp(self.format, SYS_ENDIAN) == 0:
                            self.is_same_endian = 1
                        else:
                            self.is_same_endian = 0
                    token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    if strcmp(token, VERSION) == 0:
                        self.version = <char*>malloc(strlen(token)+1)
                        strcpy(self.version, token)
                    else:
                        return 0
                elif strcmp(token, END_HEADER) == 0:
                    return 1
                else:
                    return 0
                buf_ptr = buffer
                buf_len = 0
            else:
                # Reallocate.
                buf_size += buf_size
                ptr_to_buf[0] = <char*>realloc(ptr_to_buf[0], sizeof(char) * buf_size)
                buffer = ptr_to_buf[0]
                num_get = buf_size - bytes_read-1
                # buf_len accumulates bytes_read across lines
                buf_ptr = &buffer[buf_len]
        return 0

    cdef int read_parse_body_ascii(self, FILE* fp, char** ptr_to_buf, size_t buf_size) nogil:
        cdef char* buffer = ptr_to_buf[0]
        cdef size_t num_get = buf_size
        cdef char* buf_ptr = buffer
        cdef char* token = NULL
        cdef long pos = 0
        cdef long last_pos = 0
        cdef long bytes_read = 0
        cdef long buf_len = 0
        cdef long i, j, k, m
        cdef void* temp_count = NULL
        cdef long long_count = 0
        cdef PLYElement* elem = NULL
        cdef PLYProp* prop = NULL
        cdef size_t type_size = 0
        cdef size_t count_type_size = 0

        pos = ftell(fp)
        i = 0
        k = 0
        while fgets(buf_ptr, num_get, fp):
            if i == self.num_elements:
                return 0
            last_pos = pos
            pos = ftell(fp)
            bytes_read = pos - last_pos
            buf_len += bytes_read
            if buf_ptr[bytes_read-1] == '\r' or buf_ptr[bytes_read-1] == '\n':
                elem = &self.elements[i]
                token = strtok(buffer, DELIMETERS)
                for j in range(elem.num_props):
                    prop = &elem.props[j]
                    if j > 0: token = strtok(NULL, DELIMETERS)
                    if token == NULL:
                        return 0
                    type_size = PLY.size_of_type(prop.type)
                    if type_size == 0:
                        return 0
                    if prop.count_type == NO_TYPE:
                        # Pointer arithmatic is used here to get the
                        # correct address, correctly aligning the
                        # void pointer with the intended type rather
                        # that casting then using array-style syntax.
                        if PLY.cast_ascii_data(prop.data+(k*type_size),
                            prop.type, token) == NULL:
                            return 0
                    else:
                        count_type_size = PLY.size_of_type(prop.count_type)
                        temp_count = <void*>malloc(sizeof(count_type_size))
                        if PLY.cast_ascii_data(temp_count, prop.count_type, token) == NULL:
                            return 0
                        prop.count[k] = PLY.data_to_long(temp_count, prop.count_type)
                        long_count = prop.count[k]
                        free(temp_count)
                        temp_count = NULL
                        if long_count == 0:
                            return 0
                        prop.data_list[k] = <void*>malloc(
                            type_size * long_count)
                        for m in range(long_count):
                            token = strtok(NULL, DELIMETERS)
                            if token == NULL:
                                return 0
                            # Pointer arithmatic is used here to get the
                            # correct address, correctly aligning the
                            # void pointer with the intended type rather
                            # that casting then using array-style syntax.
                            if PLY.cast_ascii_data(prop.data_list[k]+(m*type_size),
                                prop.type, token) == NULL:
                                return 0
                k += 1
                if k == elem.count:
                    i += 1
                    k = 0
            else:
                # Reallocate.
                buf_size += buf_size
                ptr_to_buf[0] = <char*>realloc(ptr_to_buf[0], sizeof(char) * buf_size+1)
                buffer = ptr_to_buf[0]
                num_get = buf_size - bytes_read-1
                # buf_len accumulates bytes_read across lines
                buf_ptr = &buffer[buf_len]
        return 1

    cdef int read_parse_body_binary(self, FILE* fp, char** ptr_to_buf) nogil:
        cdef long start_pos = ftell(fp)
        fseek(fp, 0, SEEK_END)
        cdef long end_pos = ftell(fp)
        cdef long buf_size = end_pos - start_pos
        ptr_to_buf[0] = <char*>realloc(ptr_to_buf[0], sizeof(char) * buf_size)
        cdef char* buffer = ptr_to_buf[0]
        cdef char* buf_ptr = buffer
        cdef int i, j, k, m
        cdef void* temp_count = NULL
        cdef long long_count = 0
        cdef PLYElement* elem = NULL
        cdef PLYProp* prop = NULL
        cdef size_t type_size = 0
        cdef size_t count_type_size = 0
        cdef size_t bytes_switched = 0

        if buffer == NULL:
            return 0

        fseek(fp, start_pos, SEEK_SET)
        fread(buffer, 1, buf_size, fp)

        for i in range(self.num_elements):
            elem = &self.elements[i]
            for j in range(elem.count):
                for k in range(elem.num_props):
                    prop = &elem.props[k]
                    if prop.count_type == NO_TYPE:
                        type_size = PLY.size_of_type(prop.type)
                        if self.is_same_endian == 0:
                            if type_size > 1:
                                bytes_switched = PLY.switch_endian(buf_ptr, type_size)
                                if bytes_switched == 0:
                                    return 0
                        # Pointer arithmatic is used here to get the
                        # correct address, correctly aligning the
                        # void pointer with the intended type rather
                        # that casting then using array-style syntax.
                        if PLY.cast_binary_data(prop.data+(j*type_size),
                            prop.type, buf_ptr) == NULL:
                            return 0
                        buf_ptr += type_size
                    else:
                        count_type_size = PLY.size_of_type(prop.count_type)
                        temp_count = <void*>malloc(sizeof(count_type_size))
                        if self.is_same_endian == 0:
                            if count_type_size > 1:
                                bytes_switched = PLY.switch_endian(buf_ptr, count_type_size)
                                if bytes_switched == 0:
                                    return 0
                        if PLY.cast_binary_data(temp_count, prop.count_type, buf_ptr) == NULL:
                            return 0
                        prop.count[j] = PLY.data_to_long(temp_count, prop.count_type)
                        long_count = prop.count[j]
                        free(temp_count)
                        temp_count = NULL
                        if long_count == 0:
                            return 0
                        buf_ptr += count_type_size
                        type_size = PLY.size_of_type(prop.type)
                        prop.data_list[j] = <void*>malloc(type_size * long_count)
                        for m in range(long_count):
                            if self.is_same_endian == 0:
                                if type_size > 1:
                                    bytes_switched = PLY.switch_endian(buf_ptr, type_size)
                                    if bytes_switched == 0:
                                        return 0
                            # Pointer arithmatic is used here to get the
                            # correct address, correctly aligning the
                            # void pointer with the intended type rather
                            # that casting then using array-style syntax.
                            if PLY.cast_binary_data(prop.data_list[j]+(m*type_size),
                                prop.type, buf_ptr) == NULL:
                                return 0
                            buf_ptr += type_size
        return 1

    @staticmethod
    cdef char map_type(char* token) nogil:
        if strcmp(token, TYPE_CHAR) == 0: return 'c'
        elif strcmp(token, TYPE_UCHAR) == 0: return 'C'
        elif strcmp(token, TYPE_SHORT) == 0: return 's'
        elif strcmp(token, TYPE_USHORT) == 0: return 'S'
        elif strcmp(token, TYPE_INT) == 0: return 'i'
        elif strcmp(token, TYPE_UINT) == 0: return 'I'
        elif strcmp(token, TYPE_FLOAT) == 0: return 'f'
        elif strcmp(token, TYPE_DOUBLE) == 0: return 'd'
        elif strcmp(token, TYPE_INT8) == 0: return 'c'
        elif strcmp(token, TYPE_UINT8) == 0: return 'C'
        elif strcmp(token, TYPE_INT16) == 0: return 's'
        elif strcmp(token, TYPE_UINT16) == 0: return 'S'
        elif strcmp(token, TYPE_INT32) == 0: return 'i'
        elif strcmp(token, TYPE_UINT32) == 0: return 'I'
        elif strcmp(token, TYPE_FLOAT32) == 0: return 'f'
        elif strcmp(token, TYPE_FLOAT64) == 0: return 'd'
        else:
            return NO_TYPE

    @staticmethod
    cdef void* cast_ascii_data(void* data, char type, char* token) nogil:
        cdef long temp_long
        cdef unsigned long temp_ulong
        cdef float temp_float

        errno = 0
        if type == 'c':
            temp_long = strtol(token, NULL, 10)
            if errno == ERANGE: return NULL
            if temp_long >= INT8_MIN and temp_long <= INT8_MAX:
                (<int8_t*>data)[0] = <int8_t>temp_long
                return data
            else: return NULL
        elif type == 'C':
            temp_ulong = strtoul(token, NULL, 10)
            if errno == ERANGE: return NULL
            if temp_ulong <= UINT8_MAX:
                (<uint8_t*>data)[0] = <uint8_t>temp_ulong
                return data
            else: return NULL
        elif type == 's':
            temp_long = strtol(token, NULL, 10)
            if errno == ERANGE: return NULL
            if temp_long >= INT16_MIN and temp_long <= INT16_MAX:
                (<int16_t*>data)[0] = <int16_t>temp_long
                return data
            else: return NULL
        elif type == 'S':
            temp_ulong = strtoul(token, NULL, 10)
            if errno == ERANGE: return NULL
            if temp_ulong <= UINT16_MAX:
                (<uint16_t*>data)[0] = <uint16_t>temp_ulong
                return data
            else: return NULL
        elif type == 'i':
            temp_long = strtol(token, NULL, 10)
            if errno == ERANGE: return NULL
            if temp_long >= INT32_MIN and temp_long <= INT32_MAX:
                (<int32_t*>data)[0] = <int32_t>temp_long
                return data
            else: return NULL
        elif type == 'I':
            temp_ulong = strtoul(token, NULL, 10)
            if errno == ERANGE: return NULL
            if temp_ulong <= UINT32_MAX:
                (<uint32_t*>data)[0] = <uint32_t>temp_ulong
                return data
            else: return NULL
        elif type == 'f':
            temp_float = strtof(token, NULL)
            (<float*>data)[0] = <float>temp_float
            if errno == ERANGE: return NULL
            else: return data
        elif type == 'd':
            temp_float = strtof(token, NULL)
            (<double*>data)[0] = <double>temp_float
            if errno == ERANGE: return NULL
            else: return data
        else:
            return NULL

    @staticmethod
    cdef void* cast_binary_data(char* data, char type, char* bytes) nogil:
        if type == 'c':
            (<int8_t*>data)[0] = (<int8_t*>bytes)[0]
        elif type == 'C':
            (<uint8_t*>data)[0] = (<uint8_t*>bytes)[0]
        elif type == 's':
            (<int16_t*>data)[0] = (<int16_t*>bytes)[0]
        elif type == 'S':
            (<uint16_t*>data)[0] = (<uint16_t*>bytes)[0]
        elif type == 'i':
            (<int32_t*>data)[0] = (<int32_t*>bytes)[0]
        elif type == 'I':
            (<uint32_t*>data)[0] = (<uint32_t*>bytes)[0]
        elif type == 'f':
            (<float*>data)[0] = (<float*>bytes)[0]
        elif type == 'd':
            (<double*>data)[0] = (<double*>bytes)[0]
        else:
            return NULL
        return data

    @staticmethod
    cdef size_t size_of_type(char type) nogil:
        if type == 'c': return SIZE_INT8
        elif type == 'C': return SIZE_UINT8
        elif type == 's': return SIZE_INT16
        elif type == 'S': return SIZE_UINT16
        elif type == 'i': return SIZE_INT32
        elif type == 'I': return SIZE_UINT32
        elif type == 'f': return SIZE_FLOAT
        elif type == 'd': return SIZE_DOUBLE
        else:
            return 0

    @staticmethod
    cdef long data_to_long(void* data, char type) nogil:
        if type == 'c': return <long>(<int8_t*>data)[0]
        elif type == 'C': return <long>(<uint8_t*>data)[0]
        elif type == 's': return <long>(<int16_t*>data)[0]
        elif type == 'S': return <long>(<uint16_t*>data)[0]
        elif type == 'i': return <long>(<int32_t*>data)[0]
        elif type == 'I': return <long>(<uint32_t*>data)[0]
        elif type == 'f': return <long>(<float*>data)[0]
        elif type == 'd': return <long>(<double*>data)[0]
        else:
            return 0

    @staticmethod
    cdef size_t switch_endian(char* bytes, size_t type_size) nogil:
        if type_size == 2:
            PLY.switch_endian2(bytes)
        elif type_size == 4:
            PLY.switch_endian4(bytes)
        elif type_size == 8:
            PLY.switch_endian8(bytes)
        else:
            return 0
        return type_size

    @staticmethod
    cdef void switch_endian2(char* bytes) nogil:
        cdef char old_bytes[2]
        old_bytes[0] = bytes[0]
        old_bytes[1] = bytes[1]
        bytes[0] = old_bytes[1]
        bytes[1] = old_bytes[0]

    @staticmethod
    cdef void switch_endian4(char* bytes) nogil:
        cdef char old_bytes[4]
        old_bytes[0] = bytes[0]
        old_bytes[1] = bytes[1]
        old_bytes[2] = bytes[2]
        old_bytes[3] = bytes[3]
        bytes[0] = old_bytes[3]
        bytes[1] = old_bytes[2]
        bytes[2] = old_bytes[1]
        bytes[3] = old_bytes[0]

    @staticmethod
    cdef void switch_endian8(char* bytes) nogil:
        cdef char old_bytes[8]
        old_bytes[0] = bytes[0]
        old_bytes[1] = bytes[1]
        old_bytes[2] = bytes[2]
        old_bytes[3] = bytes[3]
        old_bytes[4] = bytes[4]
        old_bytes[5] = bytes[5]
        old_bytes[6] = bytes[6]
        old_bytes[7] = bytes[7]
        bytes[0] = old_bytes[7]
        bytes[1] = old_bytes[6]
        bytes[2] = old_bytes[5]
        bytes[3] = old_bytes[4]
        bytes[4] = old_bytes[3]
        bytes[5] = old_bytes[2]
        bytes[6] = old_bytes[1]
        bytes[7] = old_bytes[0]

    '''def get_vertices_for_format(self, str format_name):
        vertex_formats = format_registrar._vertex_formats
        cdef FormatConfig format_config = vertex_formats[format_name]

        return format_config.format_dict'''

    cdef PLYElement* get_element_by_name(self, char* name) nogil:
        cdef long i
        cdef PLYElement* elem

        for i in range(self.num_elements):
            elem = &self.elements[i]
            if strcmp(elem.name, name) == 0:
                return elem
        return NULL

    @staticmethod
    cdef PLYProp* get_property_by_name(PLYElement* elem, char* name) nogil:
        cdef long i
        cdef PLYProp* prop

        for i in range(elem.num_props):
            prop = &elem.props[i]
            if strcmp(prop.name, name) == 0:
                return prop
        return NULL

    @staticmethod
    cdef int property_is_list(PLYProp* prop) nogil:
        if prop.count_type == NO_TYPE:
            return 0
        return 1

    def __dealloc__(self):
        cdef long i, j, k
        cdef PLYElement* elem
        cdef PLYProp* prop

        free(self.format)
        free(self.version)
        for i in range(self.num_elements):
            elem = &self.elements[i]
            free(elem.name)
            for j in range(elem.num_props):
                prop = &elem.props[j]
                free(prop.name)
                if prop.count_type != NO_TYPE:
                    for k in range(elem.count):
                        free(prop.data_list[k])
                    free(prop.count)
                    free(prop.data_list)
                else:
                    free(prop.data)
            if elem.num_props > 0:
                free(elem.props)
        free(self.elements)

    def __repr__(self):
        return 'PLY({})'.format(self.filename)

    def __str__(self):
        '''
            Expect this to take a long time for large files.
            Not recommended for any use beyond a pretty-print for debugging.
        '''
        if self._is_loaded:
            s = '''
Loaded PLY File: {}
Format: {}
Version: {}
No. Elements: {}'''.format(self.filename, self.format, self.version,
    self.num_elements)
            for i in range(self.num_elements):
                element = self.elements[i]
                s +='''
Element: {}
    Count: {}
    No. Properties: {}'''.format(element.name, element.count, element.num_props)
                for j in range(element.num_props):
                    prop = element.props[j]
                    d = '['
                    if prop.count_type != NO_TYPE:
                        for k in range(element.count):
                            char_type = chr(prop.type)
                            prop_count = prop.count[k]
                            d += '['
                            for m in range(prop_count):
                                if char_type == 'c':
                                    d+= str((<int8_t**>prop.data_list)[k][m])
                                elif char_type == 'C':
                                    d+= str((<uint8_t**>prop.data_list)[k][m])
                                elif char_type == 's':
                                    d+= str((<int16_t**>prop.data_list)[k][m])
                                elif char_type == 'S':
                                    d+= str((<uint16_t**>prop.data_list)[k][m])
                                elif char_type == 'i':
                                    d+= str((<int32_t**>prop.data_list)[k][m])
                                elif char_type == 'I':
                                    d+= str((<uint32_t**>prop.data_list)[k][m])
                                elif char_type == 'f':
                                    d+= str((<float**>prop.data_list)[k][m])
                                elif char_type == 'd':
                                    d+= str((<double**>prop.data_list)[k][m])
                                if m < prop_count-1:
                                    d += ', '
                            d += ']'
                            if k < element.count-1:
                                d += ', '
                    else:
                        for k in range(element.count):
                            char_type = chr(prop.type)
                            if char_type == 'c':
                                d += str((<int8_t*>prop.data)[k])
                            elif char_type == 'C':
                                d += str((<uint8_t*>prop.data)[k])
                            elif char_type == 's':
                                d += str((<int16_t*>prop.data)[k])
                            elif char_type == 'S':
                                d += str((<uint16_t*>prop.data)[k])
                            elif char_type == 'i':
                                d += str((<int32_t*>prop.data)[k])
                            elif char_type == 'I':
                                d += str((<uint32_t*>prop.data)[k])
                            elif char_type == 'f':
                                d += str((<float*>prop.data)[k])
                            elif char_type == 'd':
                                d += str((<double*>prop.data)[k])
                            if k < element.count-1:
                                d += ', '
                    d += ']'
                    s += '''
    Property: {}
        List: {}
        Type: {}
        Data: {}'''.format(prop.name, bool(prop.count_type),
            chr(prop.type), d)
            return s
        else:
            return 'Unloaded PLY File: {}'.format(self.filename)

cdef class VertexFormatPropertyMap:
    def __cinit__(self):
        self._ply_properties = {}

    property ply_properties:
        def __get__(self):
            return self._ply_properties

    def map_props_to_format(self, dict props, str format_name):
        vertex_formats = format_registrar._vertex_formats
        cdef FormatConfig format_config = vertex_formats[format_name]
        format_dict = format_config.format_dict

        if not len(props) == len(format_dict):
            raise ValueError('Wrong nubmer of properties for vertex format.')
        for attrib_name in props:
            attrib_len = format_dict[attrib_name][0]
            if not len(props[attrib_name]) == attrib_len:
                raise ValueError('Wrong nubmer of properties for vertex format.')
        self._ply_properties[format_name] = props

vertex_format_prop_map = VertexFormatPropertyMap()

vertex_format_3d_5f_props = {
    'pos': ('x', 'y', 'z'),
    'uvs': ('s', 't')
}

vertex_format_prop_map.map_props_to_format(
    vertex_format_3d_5f_props, 'vertex_format_3d_5f'
    )

vertex_format_3d_5f4ub_props = {
    'pos': ('x', 'y', 'z'),
    'uvs': ('s', 't'),
    'v_color': ('red', 'green', 'blue', 'alpha')
}

vertex_format_prop_map.map_props_to_format(
    vertex_format_3d_5f4ub_props, 'vertex_format_3d_5f4ub'
    )

vertex_format_3d_3f4ub_props = {
    'pos': ('x', 'y', 'z'),
    'v_color': ('red', 'green', 'blue', 'alpha')
}

vertex_format_prop_map.map_props_to_format(
    vertex_format_3d_3f4ub_props, 'vertex_format_3d_3f4ub'
    )
