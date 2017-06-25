from gamesystem cimport GameSystem
from kivy.graphics.transformation cimport Matrix

cdef class GameView3D(GameSystem):
    cdef Matrix view_mat
    cdef Matrix projection_mat
    cdef list _touches
    cdef int _touch_count
    cdef void _update_view_matrix(GameView3D self)
    cdef void _update_projection_matrix(GameView3D self)
