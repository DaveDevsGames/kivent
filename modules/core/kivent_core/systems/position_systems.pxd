from staticmemgamesystem cimport StaticMemGameSystem, MemComponent


ctypedef struct PositionStruct2D:
    unsigned int entity_id
    float x
    float y


cdef class PositionComponent2D(MemComponent):
    pass


cdef class PositionSystem2D(StaticMemGameSystem):
    pass


ctypedef struct PositionStruct3D:
    unsigned entity_id
    float x
    float y
    float z


cdef class PositionComponent3D(MemComponent):
    pass


cdef class PositionSystem3D(StaticMemGameSystem):
    pass
