from tart.imaging.visibility import Visibility_Load
from tart.util import skyloc
from tart.util import angle

import unittest
import numpy as np

class TestVisibility(unittest.TestCase):

  def setUp(self):
    self.v_array = Visibility_Load('test_data/measured_visibility.vis')


  def test_zero_rotation(self):
    v_array = Visibility_Load('test_data/measured_visibility.vis')
    for v in v_array:
      v_before = np.array(v.v) # Copy the visibilities
      el1 = v.phase_el
      az1 = v.phase_az

      ra, decl = v.config.get_loc().horizontal_to_equatorial(v.timestamp, el1, az1)
      v.rotate(skyloc.Skyloc(ra, decl))
      v_after = np.array(v.v)
      self.assertEqual(v.phase_el.to_degrees(), el1.to_degrees())
      # self.assertEqual(v.phase_az.to_degrees(), az1.to_degrees())
      for x,y in zip(v_before, v_after):
        self.assertAlmostEqual(x,y)

  def test_full_rotation(self):
    v = self.v_array[0]
    v_before = np.array(v.v) # Copy the visibilities
    el1 = v.phase_el
    az1 = v.phase_az
    ra, decl = v.config.get_loc().horizontal_to_equatorial(v.timestamp, el1, az1)

    # Pick a baseline


    # Calculate the angle to offset the RA, DEC to produce a full rotation
    #

    v.rotate(skyloc.Skyloc(ra + angle.from_dms(0.05), decl))
    v_after = np.array(v.v)
    self.assertAlmostEqual(v.phase_el.to_degrees(), el1.to_degrees(), 0)
    for x,y in zip(v_before, v_after):
      self.assertAlmostEqual(np.angle(x),np.angle(y),1)
      self.assertAlmostEqual(np.abs(x),np.abs(y),2)
