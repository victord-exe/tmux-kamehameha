"""Chequeos de mundito: config (default, roto, recortes) y tamaño de los frames. Correr: python3 -m unittest extras/mundito/test_mundito.py"""
import json, os, re, tempfile, unittest
import importlib.util
from importlib.machinery import SourceFileLoader

HERE = os.path.dirname(os.path.abspath(__file__))
ANSI = re.compile(r"\x1b\[[0-9;]*[mK]")

def load(config=None, raw=None):
    """Carga mundito con un config dado (dict, texto crudo o ruta inexistente)."""
    path = os.path.join(tempfile.mkdtemp(), "config.json")
    if config is not None or raw is not None:
        with open(path, "w") as f: f.write(raw if raw is not None else json.dumps(config))
    os.environ["MUNDITO_CONFIG"] = path
    loader = SourceFileLoader(f"mundito_{id(path)}", os.path.join(HERE, "mundito"))  # sin .py: loader explícito
    mod = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(mod)
    return mod

class Config(unittest.TestCase):
    def test_sin_config_usa_el_ejemplo(self):
        m = load()
        self.assertEqual([o[-1] for o in m.ORBITS], [o["items"] for o in m.DEFAULT["orbits"]])

    def test_json_roto_usa_el_ejemplo(self):
        self.assertEqual(len(load(raw="{roto").ORBITS), 3)

    def test_recorta_items_largos_y_orbitas_de_mas(self):
        o = {"color": "#ff0000", "glyph": "★★", "items": ["x" * 40] + [str(i) for i in range(9)]}
        m = load({"orbits": [o] * 5})
        self.assertEqual(len(m.ORBITS), 3)                 # solo caben 3 órbitas
        self.assertEqual(len(m.ORBITS[0][-1]), 6)          # hasta 6 items
        self.assertEqual(len(m.ORBITS[0][-1][0]), 18)      # nombres de hasta 18
        self.assertEqual(m.ORBITS[0][1], "★")              # glyph de un caracter

    def test_color_invalido_no_revienta(self):
        m = load({"orbits": [{"color": "rojo", "items": ["a"]}]})
        self.assertEqual(len(m.ORBITS), 1)

class Frames(unittest.TestCase):
    def test_frame_tiene_rows_filas_y_no_se_pasa_del_ancho(self):
        m = load()
        for cols in (m.W, 60):
            rows = m.render(m.frame(40), 40, cols)
            self.assertEqual(len(rows), m.ROWS)
            self.assertTrue(all(len(ANSI.sub("", r)) <= cols for r in rows))

    def test_el_cerebro_cabe_en_la_escena(self):
        m = load()
        self.assertGreater(len(m.CELLS), 300)
        self.assertTrue(all(0 <= x < m.W and 0 <= y < m.H for x, y in m.CELLS))

if __name__ == "__main__":
    unittest.main()
