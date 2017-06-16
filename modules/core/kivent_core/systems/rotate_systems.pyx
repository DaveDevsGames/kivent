# cython: embedsignature=True
from staticmemgamesystem cimport StaticMemGameSystem, MemComponent
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivy.factory import Factory
from kivy.properties import ObjectProperty, NumericProperty, StringProperty

cdef class RotateComponent2D(MemComponent):
    '''The component associated with RotateSystem2D.

    **Attributes:**
        **entity_id** (unsigned int): The entity_id this component is currently
        associated with. Will be <unsigned int>-1 if the component is
        unattached.

        **r** (float): The rotation around center of the entity.
    '''

    property entity_id:
        def __get__(self):
            cdef RotateStruct2D* data = <RotateStruct2D*>self.pointer
            return data.entity_id

    property r:
        def __get__(self):
            cdef RotateStruct2D* data = <RotateStruct2D*>self.pointer
            return data.r
        def __set__(self, float value):
            cdef RotateStruct2D* data = <RotateStruct2D*>self.pointer
            data.r = value


cdef class RotateSystem2D(StaticMemGameSystem):
    '''
    RotateSystem2D abstracts 2 dimensional rotation data out into its own
    system so that all other GameSystem can interact with the rotation of an
    Entity without having to know specifically about dependent systems such as
    the CymunkPhysics system or any other method of determining the actual
    rotation. This GameSystem does no processing of its own, just holding data.

    Typically other GameSystems will interpret this rotation as being a
    rotation around the center of the entity.
    '''
    type_size = NumericProperty(sizeof(RotateStruct2D))
    component_type = ObjectProperty(RotateComponent2D)
    system_id = StringProperty('rotate')

    def init_component(self, unsigned int component_index,
        unsigned int entity_id, str zone, float r):
        '''A RotateComponent2D is always initialized with a single float
        representing a rotation in degrees.
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef RotateStruct2D* component = <RotateStruct2D*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        component.r = r

    def clear_component(self, unsigned int component_index):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef RotateStruct2D* pointer = <RotateStruct2D*>(
            memory_zone.get_pointer(component_index))
        pointer.entity_id = -1
        pointer.r = 0.


Factory.register('RotateSystem2D', cls=RotateSystem2D)


cdef class RotateComponent3D(MemComponent):
    '''The component associated with RotateSystem3D.

    **Attributes:**
        **entity_id** (unsigned int): The entity_id this component is currently
        associated with. Will be <unsigned int>-1 if the component is
        unattached.

        **axis_x** (float): The x component of the rotational axis vector.

        **axis_y** (float): The y component of the rotational axis vector.

        **axis_z** (float): The z component of the rotational axis vector.

        **axis** (tuple): An (x, y, z) tuple of the rotational axis vector.

        **angle** (float): The rotation around center of the entity.
    '''

    property entity_id:
        def __get__(self):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            return data.entity_id

    property axis_x:
        def __get__(self):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            return data.axis_x
        def __set__(self, float value):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            data.axis_x = value

    property axis_y:
        def __get__(self):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            return data.axis_y
        def __set__(self, float value):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            data.axis_y = value

    property axis_z:
        def __get__(self):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            return data.axis_z
        def __set__(self, float value):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            data.axis_z = value

    property axis:
        def __get__(self):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            return (data.axis_x, data.axis_y, data.axis_z)
        def __set__(self, tuple new_axis):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            data.axis_x = new_axis[0]
            data.axis_y = new_axis[1]
            data.axis_z = new_axis[2]

    property angle:
        def __get__(self):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            return data.angle
        def __set__(self, float value):
            cdef RotateStruct3D* data = <RotateStruct3D*>self.pointer
            data.angle = value


cdef class RotateSystem3D(StaticMemGameSystem):
    '''
    RotateSystem3D abstracts 3 dimensional rotation data out into its own
    system so that all other GameSystem can interact with the rotation of an
    Entity without having to know specifically about dependent systems.
    This GameSystem does no processing of its own, just holding data.

    Typically other GameSystems will interpret this rotation as being a
    rotation around the axis through the center of the entity. This system
    does not normalize the axis and will simply store the data fed to it.
    '''
    type_size = NumericProperty(sizeof(RotateStruct3D))
    component_type = ObjectProperty(RotateComponent3D)
    system_id = StringProperty('rotate3d')

    def init_component(self, unsigned int component_index,
        unsigned int entity_id, str zone, args):
        '''A RotateComponent3D is initialized with an args tuple of
        (x, y, z, angle) where x, y, and z represent an axis vector.
        '''
        cdef float axis_x = args[0]
        cdef float axis_y = args[1]
        cdef float axis_z = args[2]
        cdef float angle = args[3]
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef RotateStruct3D* component = <RotateStruct3D*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        component.axis_x = axis_x
        component.axis_y = axis_y
        component.axis_z = axis_z
        component.angle = angle

    def clear_component(self, unsigned int component_index):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef RotateStruct3D* pointer = <RotateStruct3D*>(
            memory_zone.get_pointer(component_index))
        pointer.entity_id = -1
        pointer.axis_x = 0.
        pointer.axis_y = 0.
        pointer.axis_z = 1.
        pointer.angle = 0.


Factory.register('RotateSystem3D', cls=RotateSystem3D)
