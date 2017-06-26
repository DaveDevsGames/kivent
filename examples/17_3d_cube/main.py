from kivy.app import App
from kivy.uix.widget import Widget
from kivy.clock import Clock
from kivy.core.window import Window
import kivent_core
from kivent_core.gameworld import GameWorld
from kivent_core.systems.renderers_3d import RotatePolyRenderer3D
from kivent_core.systems.position_systems import PositionSystem3D
from kivent_core.systems.rotate_systems import RotateSystem3D
from kivent_core.systems.gameview_3d import GameView3D
from kivent_core.systems.gamesystem import GameSystem
from kivy.properties import StringProperty
from kivy.factory import Factory
from os.path import dirname, join, abspath

class SpinSystem3D(GameSystem):
    def update(self, dt):
        entities = self.gameworld.entities
        for component in self.components:
            if component is not None:
                entity_id = component.entity_id
                entity = entities[entity_id]
                rot_comp = entity.rotate3d
                rot_comp.angle += component.angle * dt
                if rot_comp.angle > 360.0:
                    rot_comp.angle = rot_comp.angle - 360.0
                if rot_comp.angle < -360.0:
                    rot_comp.angle = rot_comp.angle + 360.0

Factory.register('SpinSystem3D', cls=SpinSystem3D)

class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.gameworld.init_gameworld(
            ['rotate_poly_renderer3d', 'rotate3d', 'position3d', 'spin3d', 'camera3d'],
            callback = self.init_game)
        self.entities = []

    def init_game(self):
        self.setup_states()
        self.load_cube()
        self.set_state()
        self.draw_cube()

    def setup_states(self):
        self.gameworld.add_state(state_name = 'main',
            systems_added = ['rotate_poly_renderer3d'],
            systems_removed = [],
            systems_paused = [],
            systems_unpaused = ['rotate_poly_renderer3d', 'spin3d'],
            screenmanager_screen = 'main')

    def set_state(self):
        self.gameworld.state = 'main'

    def load_cube(self):
        texture_manager = self.gameworld.texture_manager
        texture_manager.load_atlas(join(dirname(dirname(abspath(__file__))), 'assets',
            'background_objects.atlas'))
        vertex_dict = {
            0: {'pos': (-10.0, -10.0, 10.0), 'v_color': (255, 255, 255, 255)},
            1: {'pos': (10.0, -10.0, 10.0), 'v_color': (0, 255, 255, 255)},
            2: {'pos': (10.0, 10.0, 10.0), 'v_color': (0, 0, 255, 255)},
            3: {'pos': (-10.0, 10.0, 10.0), 'v_color': (255, 0, 255, 255)},
            4: {'pos': (-10.0, -10.0, -10.0), 'v_color': (255, 255, 0, 255)},
            5: {'pos': (10.0, -10.0, -10.0), 'v_color': (0, 255, 0, 255)},
            6: {'pos': (10.0, 10.0, -10.0), 'v_color': (0, 0, 0, 255)},
            7: {'pos': (-10.0, 10.0, -10.0), 'v_color': (255, 0, 0, 255)}
        }
        index_list = [0, 1, 2, 2, 3, 0,
            0, 4, 5, 5, 1, 0,
            1, 5, 6, 6, 2, 1,
            2, 6, 7, 7, 3, 2,
            3, 7, 4, 4, 0, 3,
            6, 5, 4, 4, 7, 6]
        model_manager = self.gameworld.model_manager
        model_manager.load_model('vertex_format_3d_3f4ub', 8, 36, 'cube',
            indices = index_list, vertices = vertex_dict)

    def draw_cube(self):
        create_dict = {
            'position3d': (0.0, 0.0, 0.0),
            'rotate3d': (0.0, 0.0, 1.0, 0.0),
            'spin3d': {
                'angle': 90.0
            },
            'rotate_poly_renderer3d': {
                'model_key': 'cube'
            }
        }
        entity = self.gameworld.init_entity(create_dict,
            ['position3d', 'rotate3d', 'spin3d', 'rotate_poly_renderer3d'])
        self.entities.append(entity)

class DebugPanel(Widget):
    fps = StringProperty(None)

    def __init__(self, **kwargs):
        super(DebugPanel, self).__init__(**kwargs)
        Clock.schedule_once(self.update_fps)

    def update_fps(self,dt):
        self.fps = str(int(Clock.get_fps()))
        Clock.schedule_once(self.update_fps, .05)

class YourAppNameApp(App):
    def build(self):
        Window.clearcolor = (0.0, 0.0, 0.0, 1.0)

if __name__ == '__main__':
    YourAppNameApp().run()
