import unittest
import numpy as np

from tart.util import utc

from tart.simulation.antennas import *

class TestAntenna(unittest.TestCase):
  def test_90(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [0., 1., 0.])
    el = angle.from_dms(90)
    az = angle.from_dms(0)
    self.assertAlmostEqual(a0.get_geo_delay_horizontal(el, az), 0.0)
    self.assertAlmostEqual(a1.get_geo_delay_horizontal(el, az), 0.0)
    self.assertAlmostEqual(get_geo_delay_horizontal(a0, a1, el, az), 0.0)

  def test_60(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [0., 1., 0.])
    el = angle.from_dms(60)
    az = angle.from_dms(0)
    self.assertAlmostEqual(a0.get_geo_delay_horizontal(el, az), 0.0)
    self.assertAlmostEqual(a1.get_geo_delay_horizontal(el, az)*constants.V_LIGHT, -0.5) # a1 is closer to origin so negative
    self.assertAlmostEqual(get_geo_delay_horizontal(a0, a1, el, az)*constants.V_LIGHT, -0.5) # t_a1 - t_a0 negative
    self.assertAlmostEqual(get_geo_delay_horizontal(a1, a0, el, az)*constants.V_LIGHT, 0.5)

  def test_symmetry(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [0., 1., 0.])
    el = angle.from_dms(60)
    az = angle.from_dms(180)
    self.assertAlmostEqual(a0.get_geo_delay_horizontal(el, az), 0.0)
    self.assertAlmostEqual(a1.get_geo_delay_horizontal(el, az)*constants.V_LIGHT, 0.5) # a1 is further away, so positive

  def test_uvw(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [0., 1., 0.])
    el = angle.from_dms(90.)
    for az_deg in range(0, 360, 10):
      az = angle.from_dms(az_deg)
      utc_time = utc.now()
      ra, dec = location.Dunedin.horizontal_to_equatorial(utc_time, el, az)
      u, v, w = get_UVW(a0, a1, utc_time, ra, dec)
      self.assertAlmostEqual(u, 0.0)
      self.assertAlmostEqual(v, -1.0)
      self.assertAlmostEqual(w, 0.0)

  def test_uvw_60(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [0., 1., 0.])
    el = angle.from_dms(30.)
    az = angle.from_dms(0.)
    utc_time = utc.now()
    ra, dec = location.Dunedin.horizontal_to_equatorial(utc_time, el, az)
    u, v, w = get_UVW(a0, a1, utc_time, ra, dec)
    self.assertAlmostEqual(u, 0.0)
    self.assertAlmostEqual(v, -0.5)
    self.assertAlmostEqual(w, -0.86602540378443871)

  def test_uvw_90(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [0., 1., 0.])
    el = angle.from_dms(0.)
    az = angle.from_dms(0.)
    utc_time = utc.now()
    ra, dec = location.Dunedin.horizontal_to_equatorial(utc_time, el, az)
    u, v, w = get_UVW(a0, a1, utc_time, ra, dec)
    self.assertAlmostEqual(u, 0.0)
    self.assertAlmostEqual(v, 0.0)
    self.assertAlmostEqual(w, -1.0)

  def test_uvw_east(self):
    a0 = Antenna(location.Dunedin, [0., 0., 0.])
    a1 = Antenna(location.Dunedin, [1., 0., 0.])
    el = angle.from_dms(0.)
    az = angle.from_dms(90.) #east
    utc_time = utc.now()
    ra, dec = location.Dunedin.horizontal_to_equatorial(utc_time, el, az)
    uu, vv, ww = get_UVW(a0, a1, utc_time, ra, dec)
    self.assertAlmostEqual(uu, 0.0)
    self.assertAlmostEqual(vv, 0.0)
    self.assertAlmostEqual(ww, -1.0)

class TestAntennas(unittest.TestCase):

  def test_antennas(self):
    '''Test the construction of antenna signals'''
    ref_freq = 16.368e6
    freq_mult = 256
    sample_duration = 1e-5
    antenna_locations = [[-10.0, 0.0, 0.0], [10.0, 0.0, 0.0]]

    antennas =[Antenna(location.Dunedin, i) for i in antenna_locations]
    src = [SimulationSource(amplitude = 1.0, azimuth = angle.from_dms(0.0), elevation = angle.from_dms(20.0), sample_duration = sample_duration), \
           SimulationSource(amplitude = 0.5, azimuth = angle.from_dms(0.0), elevation = angle.from_dms(20.0), sample_duration = sample_duration)]
    radio_sampling_rate = ref_freq*freq_mult
    tb = np.arange(0, sample_duration, 1.0/radio_sampling_rate)
    from tart.imaging import antenna_model
    ant_models = [antenna_model.GpsPatchAntenna() for _ in range(2)]

    ant = antennas_signal(antennas, ant_models, src, tb)
    self.assertEqual(ant.shape, (len(antenna_locations), len(tb)))
    mu0 = ant[0, :].mean()
    self.assertLess(mu0, 0.01)
    self.assertGreater(mu0, -0.01)

    mu1 = ant[1, :].mean()
    self.assertLess(mu1, 0.01)
    self.assertGreater(mu1, -0.01)
