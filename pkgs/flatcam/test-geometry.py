import unittest

from shapely import GeometryCollection, LineString, MultiLineString, Point, Polygon

from camlib import flatten_shapely_geometry


class FlattenGeometryTests(unittest.TestCase):
    def test_nested_passes_and_multipart_preserve_geometry_and_order(self):
        polygon = Polygon(
            [(0, 0), (10, 0), (10, 10), (0, 10)],
            holes=[[(2, 2), (3, 2), (3, 3), (2, 3)]],
        )
        first = LineString([(0, 0), (1, 1)])
        second = LineString([(2, 2), (3, 3)])
        point = Point(4, 5)
        parts = GeometryCollection([MultiLineString([first, second]), point]).geoms
        result = flatten_shapely_geometry([[polygon], (parts,)])
        self.assertEqual([g.wkb for g in result], [g.wkb for g in [polygon, first, second, point]])
        self.assertEqual(len(result[0].interiors), 1)

    def test_empty_geometry_is_omitted_at_every_depth(self):
        line = LineString([(0, 0), (1, 1)])
        result = flatten_shapely_geometry(
            [Point(), [Polygon(), GeometryCollection([LineString(), line])], []]
        )
        self.assertEqual([g.wkb for g in result], [line.wkb])

    def test_simplification_reaches_nested_leaves_without_mutating_input(self):
        line = LineString([(0, 0), (1, 0.01), (2, 0)])
        result = flatten_shapely_geometry([[line]], simplify_tolerance=0.1)
        self.assertEqual(list(result[0].coords), [(0, 0), (2, 0)])
        self.assertEqual(list(line.coords), [(0, 0), (1, 0.01), (2, 0)])

    def test_invalid_nested_input_is_not_silently_discarded(self):
        with self.assertRaises(NotImplementedError):
            flatten_shapely_geometry([["not geometry"]])


if __name__ == "__main__":
    unittest.main()
