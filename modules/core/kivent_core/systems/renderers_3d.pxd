from renderers cimport Renderer

cdef class Renderer3D(Renderer):
    pass

cdef class RotateRenderer3D(Renderer3D):
    pass

cdef class ScaleRenderer3D(Renderer3D):
    pass

cdef class RotateScaleRenderer3D(Renderer3D):
    pass

cdef class PolyRenderer3D(Renderer3D):
    pass

cdef class RotatePolyRenderer3D(Renderer3D):
    pass

cdef class ColorRenderer3D(Renderer3D):
    pass
