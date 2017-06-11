from staticmemgamesystem cimport StaticMemGameSystem, MemComponent


ctypedef struct RotateStruct2D:
    unsigned int entity_id
    float r


cdef class RotateComponent2D(MemComponent):
    pass


cdef class RotateSystem2D(StaticMemGameSystem):
    pass


ctypedef struct RotateStruct3D:
    unsigned int entity_id
    float axis_x
    float axis_y
    float axis_z
    float angle


cdef class RotateComponent3D(MemComponent):
    pass


cdef class RotateSystem3D(StaticMemGameSystem):
    pass
