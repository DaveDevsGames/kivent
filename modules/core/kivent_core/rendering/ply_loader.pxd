from libc.stdio cimport FILE

cdef char* MAGIC_NUMBER
cdef char* KW_FORMAT
cdef char* KW_COMMENT
cdef char* KW_ELEMENT
cdef char* KW_PROPERTY
cdef char* KW_LIST
cdef char* END_HEADER
cdef char* FMT_ASCII
cdef char* FMT_BIN_LE
cdef char* FMT_BIN_BE
cdef char* VERSION
cdef char* TYPE_CHAR
cdef char* TYPE_UCHAR
cdef char* TYPE_SHORT
cdef char* TYPE_USHORT
cdef char* TYPE_INT
cdef char* TYPE_UINT
cdef char* TYPE_FLOAT
cdef char* TYPE_DOUBLE
# The following are non-standard type keywords used by some tools.
cdef char* TYPE_INT8
cdef char* TYPE_UINT8
cdef char* TYPE_INT16
cdef char* TYPE_UINT16
cdef char* TYPE_INT32
cdef char* TYPE_UINT32
cdef char* TYPE_FLOAT32
cdef char* TYPE_FLOAT64
cdef char* DELIMETERS
cdef size_t SIZE_INT8
cdef size_t SIZE_UINT8
cdef size_t SIZE_INT16
cdef size_t SIZE_UINT16
cdef size_t SIZE_INT32
cdef size_t SIZE_UINT32
cdef size_t SIZE_FLOAT
cdef size_t SIZE_DOUBLE

cdef size_t BUF_SIZE
cdef char NO_TYPE
cdef char* SYS_ENDIAN

cdef struct PLYProp:
    char* name
    char type
    void* data
    void** data_list
    char count_type
    long* count

cdef struct PLYElement:
    char* name
    long count
    unsigned int num_props
    PLYProp* props

cdef class PLY:
    cdef char* filename
    cdef char* format
    cdef int is_ascii
    cdef int is_same_endian
    cdef char* version
    cdef unsigned int num_elements
    cdef PLYElement* elements
    cdef bint _is_loaded
    cdef char* vertex_format_name
    cdef char* elem_name_indices
    cdef char* prop_name_indices
    cdef char* elem_name_vertices

    cdef int load(self, char* filename) nogil
    cdef int check_magic_number(self, FILE* fp, char** ptr_to_buf, size_t buf_size) nogil
    cdef int read_parse_header(self, FILE* fp, char** ptr_to_buf, size_t buf_size) nogil
    cdef int read_parse_body_ascii(self, FILE* fp, char** ptr_to_buf, size_t buf_size) nogil
    cdef int read_parse_body_binary(self, FILE* fp, char** ptr_to_buf) nogil
    @staticmethod
    cdef char map_type(char* token) nogil
    @staticmethod
    cdef void* cast_ascii_data(void* data, char type, char* token) nogil
    @staticmethod
    cdef void* cast_binary_data(void* data, char type, char* bytes) nogil
    @staticmethod
    cdef size_t size_of_type(char type) nogil
    @staticmethod
    cdef long data_to_long(void* data, char type) nogil
    @staticmethod
    cdef size_t switch_endian(char* bytes, size_t type_size) nogil
    @staticmethod
    cdef void switch_endian2(char* bytes) nogil
    @staticmethod
    cdef void switch_endian4(char* bytes) nogil
    @staticmethod
    cdef void switch_endian8(char* bytes) nogil
    cdef PLYElement* get_element_by_name(self, char* name) nogil
    @staticmethod
    cdef PLYProp* get_property_by_name(PLYElement* elem, char* name) nogil
    @staticmethod
    cdef int property_is_list(PLYProp* prop) nogil

cdef class VertexFormatPropertyMap:
    cdef dict _ply_properties
