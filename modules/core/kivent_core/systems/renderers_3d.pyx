# cython: profile=True
# cython: embedsignature=True
from renderers cimport RenderStruct, Renderer
from kivy.properties import StringProperty, ListProperty, NumericProperty
from kivy.graphics import Callback
from kivy.graphics.instructions cimport RenderContext
from kivent_core.rendering.vertex_formats cimport VertexFormat3D5F
from kivent_core.rendering.vertex_formats import vertex_format_3d_5f
from kivent_core.rendering.vertex_format cimport KEVertexFormat
from kivent_core.rendering.cmesh cimport CMesh
from kivent_core.rendering.batching cimport BatchManager, IndexedBatch
from kivy.graphics.opengl import glEnable, glDisable, GL_DEPTH_TEST
from kivy.graphics.cgl cimport GLfloat, GLushort
from kivent_core.systems.position_systems cimport PositionStruct3D
from kivent_core.rendering.model cimport VertexModel
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.systems.staticmemgamesystem cimport ComponentPointerAggregator
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivy.clock import Clock
from kivent_core.rendering.gl_debug cimport gl_log_debug_message
from functools import partial
from kivy.factory import Factory

cdef class Renderer3D(Renderer):
    '''
    Processing Depends On: PositionSystem3D, Renderer3D

    The renderer draws with the VertexFormat3D5F:

    .. code-block:: cython

        ctypedef struct VertexFormat3D5F:
            GLfloat[3] pos
            GLfloat[2] uvs


    This renderer draws entities with 3d position data.

    '''
    system_id = StringProperty('renderer3d')
    system_names = ListProperty(['renderer3d', 'position3d'])
    vertex_format_size = NumericProperty(sizeof(VertexFormat3D5F))
    model_format = StringProperty('vertex_format_3d_5f')
    shader_source = StringProperty('position3dshader.glsl')

    def __init__(self, **kwargs):
        self.canvas = RenderContext(use_parent_projection=True,
                                    nocompiler=True)
        if 'shader_source' in kwargs:
            self.canvas.shader.source = kwargs.get('shader_source')
        super(Renderer, self).__init__(**kwargs)
        with self.canvas.before:
            Callback(self._setup_gl_context)
        with self.canvas.after:
            Callback(self._reset_gl_context)
        self.update_trigger = Clock.create_trigger(partial(self.update, True))

    def _enable_depth_test(self, instruction):
        glEnable(GL_DEPTH_TEST)
        gl_log_debug_message('Renderer._enable_depth_test-glEnable')

    def _disable_depth_test(self, instruction):
        glDisable(GL_DEPTH_TEST)
        gl_log_debug_message('Renderer._disable_depth_test-glDisable')

    def _setup_gl_context(self, instruction):
        self._set_blend_func(instruction)
        self._enable_depth_test(instruction)

    def _reset_gl_context(self, instruction):
        self._reset_blend_func(instruction)
        self._disable_depth_test(instruction)

    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat3D5F), *vertex_format_3d_5f)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count,
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names],
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager

    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct3D* pos_comp
        cdef VertexFormat3D5F* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat3D5F* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat3D5F* model_vertices
        cdef VertexFormat3D5F model_vertex
        cdef unsigned int used, i, ri, component_count, n, t
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering

        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat3D5F*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for t in range(used):
                        ri = t * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct3D*>component_data[ri+1]
                            model_vertices = <VertexFormat3D5F*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = pos_comp.x + model_vertex.pos[0]
                                vertex.pos[1] = pos_comp.y + model_vertex.pos[1]
                                vertex.pos[2] = pos_comp.y + model_vertex.pos[2]
                                vertex.uvs[0] = model_vertex.uvs[0]
                                vertex.uvs[1] = model_vertex.uvs[1]
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()


Factory.register('Renderer3D', cls=Renderer3D)
