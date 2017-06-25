# cython: embedsignature=True
from gameview cimport GameView
from kivy.properties import (StringProperty, ListProperty,
    NumericProperty, BooleanProperty, ObjectProperty)
from kivy.clock import Clock
from kivent_core.managers.system_manager cimport SystemManager
from kivy.graphics.transformation cimport Matrix
from kivy.graphics import RenderContext
from kivy.factory import Factory

cdef class GameView3D(GameSystem):
    '''
    GameView3D provides a 3d camera system that will control the rendering
    view of any other **GameSystem** that has had the **gameview** property set
    **GameSystem** that have a **gameview** will be added to the GameView
    canvas instead of the GameWorld canvas. Any **GameSystem** intending to use
    this camera system should create it's **RenderContext** specifying
    **use_parent_modelview** and **use_parent_projection** as True such as in
    **Renderer3D** and it's suclasses.

    **Attributes**
        **camera_pos** (ListProperty): Current 3d position of the camera

        **camera_target** (ListProperty): Current 3d target position of
        the camera. The target position is the center of the scene that
        the camera will 'look at'.

        **camera_up** (ListProperty): Current 3d up vector of the camera.
        The up vector determines which way is 'up' and should not be
        parallel with the vector from **camera_pos** to **camera_target**

        **camera_fov** (NumericProperty): Current vertical fov (fovy) of
        the camera.

        **camera_aspect** (ListProperty): Current aspect ratio of the camera
        expressed as a tuple of width and height. The aspect ratio should
        typically be set to match the viewport dimensions.

        **camera_near** (NumericProperty): Current near plane of the camera.
        Setting this value to small may result in depth buffer precision
        issues at large z values.

        **camera_far** (NumericProperty): Current far plane of the camera.

        **render_system_order** (ListProperty): List of **system_id** in the
        desired order of rendering last to first. **GameSystem** with
        **system_id** not in **render_system_order** will be inserted at
        position 0.

    '''
    system_id = StringProperty('default_3d_gameview')
    camera_pos = ListProperty((0, 0, 0))
    camera_target = ListProperty((0, 1, 0))
    camera_up = ListProperty((0, 0, 1))
    camera_fov = NumericProperty(60.0)
    camera_aspect = ListProperty((4, 3))
    camera_near = NumericProperty(0.1)
    camera_far = NumericProperty(100.0)
    updateable = BooleanProperty(True)
    render_system_order = ListProperty([])

    def __init__(self, **kwargs):
        super(GameView3D, self).__init__(**kwargs)

        self.view_mat = Matrix()
        self._update_view_matrix()
        self.projection_mat = Matrix()
        self._update_projection_matrix()
        self._touch_count = 0
        self._touches = []
        self.canvas = RenderContext(use_parent_projection = False,
            use_parent_modelview = False)

    cdef void _update_view_matrix(self):
        '''
        Used interally by GameView3D to update the view matrix.
        '''
        cdef double x, y, z, tx, ty, tz, up_x, up_y, up_z
        x, y, z = self.camera_pos
        tx, ty, tz = self.camera_target
        up_x, up_y, up_z = self.camera_up
        self.view_mat = self.view_mat.look_at(x, y, z,
            tx, ty, tz, up_x, up_y, up_z)

    cdef void _update_projection_matrix(self):
        '''
        Used interally by GameView3D to update the projection matrix.
        '''
        cdef double fov, aspect, near, far
        fov = self.camera_fov
        aspect = self.camera_aspect[0]
        aspect /= self.camera_aspect[1]
        near = self.camera_near
        far = self.camera_far
        self.projection_mat.perspective(fov, aspect, near, far)

    def update_render_state(self):
        '''
        Used interally by GameView3D to update the modelview and
        projection matrices to properly reflect the settings for
        camera_pos, camera_target, camera_up, camera_fov, camera_aspect,
        camera_near and camera_far.
        '''
        self._update_view_matrix()
        self._update_projection_matrix()
        self.canvas['modelview_mat'] = self.view_mat
        self.canvas['projection_mat'] = self.projection_mat

    def add_widget(self, widget):
        gameworld = self.gameworld
        cdef str system_id
        cdef SystemManager system_manager = gameworld.system_manager
        if isinstance(widget, GameSystem):
            widget.on_add_system()
            render_system_order = self.render_system_order
            system_id = widget.system_id
            if system_id in render_system_order:
                index=render_system_order.index(system_id)
            else:
                index=0
            super(GameView3D, self).add_widget(widget, index=index)
            system_index = system_manager.system_index
            if widget.system_id not in system_index:
                Clock.schedule_once(lambda dt: gameworld.add_system(widget))
        else:
            super(GameView, self).add_widget(widget)

    def remove_widget(self, widget):
        if isinstance(widget, GameSystem):
            widget.on_remove_system()
        super(GameView3D, self).remove_widget(widget)

    def update(self, dt):
        self.update_render_state()


Factory.register('GameView3D', cls=GameView3D)
