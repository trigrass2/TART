'''
Generate UVFITS file from visibility object.
'''


import pyfits # easy_install pyfits
import numpy as np

from tart.imaging import tart_util

from tart.simulation import antennas

from tart.util import angle
from tart.util import skyloc
from tart.util import constants


def encode_baseline(a1, a2):
  '''Encode the baseline. Use the miriad convention to handle more than 255 antennas (up to 2048).'''
  if a1 > a2:
    te = a2
    a2 = a1
    a1 = te

  if (a2 > 255):
    return a1*2048 + a2 + 65536 # this is backwards compatible with the standard UVFITS convention
  else:
    return a1*256 + a2


def decode_baseline(bl):
  '''Decode a baseline using same (extended) miriad format as above'''
  if (bl > 65536):
    bl -= 65536
    a2 = bl % 2048
    a1 = (bl - a2)/2048
    return a1 , a2
  else:
    a2 = bl % 256
    a1 = (bl - a2)/256
    return a1 , a2


class UVFitsGenerator(object):
  ''' Generate a UVFITS file for a target source from an array of visibilities.'''
  def __init__(self, cal_vis, phase_center): # FIXME
    # self.phase_center_elevation = phase_center_elevation
    # self.phase_center_azimuth = phase_center_azimuth

    self.v_array = cal_vis_list
    self.n_baselines = len(self.v_array[0].baselines)
    self.loc = self.v_array[0].get_config().get_loc() # Assume the array isn't moving
    self.phase_center = phase_center

  def gen_vis_table(self):
    '''Generate visibility table and fill payload.'''

    baselines = []
    for v in self.v_array:
      ra, dec = self.phase_center.radec(v.timestamp)
      v.rotate(skyloc.Skyloc(ra, dec))
      for i in range(v.config.num_baselines):
        c = v.get_config()
        a0 = antennas.Antenna(c.get_loc(), c.ant_positions[v.baselines[i][0]])
        a1 = antennas.Antenna(c.get_loc(), c.ant_positions[v.baselines[i][1]])
        baseline = {}
        uu, vv, ww = antennas.get_UVW(a0, a1, v.timestamp, ra, dec)
        # print (np.array(a1.enu) - np.array(a0.enu)), uu, vv, ww
        # arcane units of UVFITS require u,v,w in nanoseconds
        baseline['UU'] = uu/constants.V_LIGHT
        baseline['VV'] = vv/constants.V_LIGHT
        baseline['WW'] = ww/constants.V_LIGHT
        baseline['BASELINE'] = encode_baseline(v.baselines[i][0]+1, v.baselines[i][1]+1)
        baseline['DATE'] = tart_util.get_julian_date(v.timestamp)- int(tart_util.get_julian_date(v.timestamp)+0.5)
        # DATE FIXME ?
        baselines.append(baseline)

    freqs = np.array([1545.])
    pols = np.array(['+'])

    data = np.zeros((len(self.v_array)*self.n_baselines, 1, 1, len(freqs), len(pols), 3))

    for i, v in enumerate(self.v_array):
      for k,  b in enumerate(v.baselines):
        for l, _ in enumerate(freqs):
          for j, _ in enumerate(pols):
            re = v.v[k].real
            img = v.v[k].imag
            w = np.ones(1)
            data[i*self.n_baselines+k, 0, 0, l, j, :] = [re, img, w]

    hdu = pyfits.GroupsHDU(pyfits.GroupData(data, parnames=['UU', 'VV', 'WW', 'BASELINE', 'DATE'], bitpix=-32, \
    pardata=[   [b['UU']        for b in baselines], \
                [b['VV']        for b in baselines], \
                [b['WW']        for b in baselines], \
                [b['BASELINE']  for b in baselines], \
                [b['DATE']      for b in baselines]]))
    return hdu


  def gen_ant_table(self):
    '''Generate antenna table.'''
    v = self.v_array[0]
    n_ant = v.config.num_antennas
    v.antennas = []
    for i in range(n_ant):
      antenna = {}
      antenna['ANNAME']  = 'ANT%i'% (i+1)     # there is no antenna 0
      antenna['STABXYZ'] = v.config.ant_positions[i]
      antenna['ORBPARM'] = 0. # SET TO 0. - not used, because 'NUMORB' in header is  0
      antenna['NOSTA']   = i+1                # there is no antenna 0
      antenna['MNTSTA']  = 0
      antenna['STAXOF']  = 0.
      antenna['POLTYA']  = 'X'
      antenna['POLAA']   = [0.]
      antenna['POLCALA'] = np.array([0., 0., 0.])
      antenna['POLTYB']  = 'Y'
      antenna['POLAB']   = [0.]
      antenna['POLCALB'] = np.array([0., 0., 0.])
      v.antennas.append(antenna)

    c1 = pyfits.Column(name='ANNAME',   format='8A', array= [a['ANNAME']  for a in v.antennas])
    c2 = pyfits.Column(name='STABXYZ',  format='3D', array= [a['STABXYZ'] for a in v.antennas], unit='METERS')
    c3 = pyfits.Column(name='NOSTA',    format='1J', array= [a['NOSTA']   for a in v.antennas])
    c4 = pyfits.Column(name='MNTSTA',   format='1J', array= [a['MNTSTA']  for a in v.antennas])
    c5 = pyfits.Column(name='STAXOF',   format='1E', array= [a['STAXOF']  for a in v.antennas], unit='METERS')
    c6 = pyfits.Column(name='POLTYA',   format='1A', array= [a['POLTYA']  for a in v.antennas])
    c7 = pyfits.Column(name='POLAA',    format='1E', array= [a['POLAA']   for a in v.antennas], unit='DEGREES')
    c8 = pyfits.Column(name='POLCALA',  format='3E', array= [a['POLCALA'] for a in v.antennas])
    c9 = pyfits.Column(name='POLTYB',   format='1A', array= [a['POLTYB']  for a in v.antennas])
    c10 = pyfits.Column(name='POLAB',   format='1E', array= [a['POLAB']   for a in v.antennas], unit='DEGREES')
    c11 = pyfits.Column(name='POLCALB', format='3E', array= [a['POLCALB'] for a in v.antennas])
    c0 = pyfits.Column(name='ORBPARM',  format='1D', array= [a['ORBPARM'] for a in v.antennas])

    return pyfits.new_table([c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c0], tbtype='BinTableHDU')


  def update_vis_header(self):
    '''Update visibility header.'''

    v = self.v_array[0]
    params = ["UU", "VV", "WW", "BASELINE", "DATE"]
    ctypes = ["STOKES", "FREQ", "RA", "DEC"]

    self.vis_header.update('OBJECT', 'Full Sky')

    # without rotation of the visibilities is has to be this:
    # ra, dec = self.loc.horizontal_to_equatorial(v.timestamp, angle.from_dms(90.), angle.from_dms(0.))
    # with rotation is has to be:

    ra, dec = self.phase_center.radec(v.timestamp)

    self.vis_header.update('OBSRA', ra.to_degrees())	# Antenna pointing center
    self.vis_header.update('OBSDEC', dec.to_degrees())	# Antenna pointing center

    self.vis_header.update('TELESCOP', 'TART')
    self.vis_header.update('INSTRUME', 'TART')
    self.vis_header.update('EPOCH', 2000.0)
    self.vis_header.update('BSCALE', 1)
    self.vis_header.update('DATE-OBS', '%i-%02i-%02iT00:00:00.0'%(v.timestamp.year, v.timestamp.month, v.timestamp.day))

    for i, par in enumerate(params):
      self.vis_header.update('PTYPE%i' % (i+1), par)
      self.vis_header.update('PSCAL%i' % (i+1), 1.0)
      self.vis_header.update('PZERO%i' % (i+1), 0.0)

    self.vis_header.update('PZERO5', int(tart_util.get_julian_date(v.timestamp) + 0.5))

    self.vis_header.update('CRVAL2', 1.0)
    self.vis_header.update('CRPIX2', 1.0)
    self.vis_header.update('CDELT2', 1.0)
    self.vis_header.update('CTYPE2', 'COMPLEX')

    for i, ctyp in enumerate(ctypes):
      self.vis_header.update('CTYPE%d' % (i+3), ctyp)
      self.vis_header.update('CRVAL%d' % (i+3), 1.0)
      self.vis_header.update('CRPIX%d' % (i+3), 1.0)
      self.vis_header.update('CDELT%d' % (i+3), 1.0)

    #set the input pol type.
    #for circular CRVAL3 should be -1, CDELT3 -1
    #for linear   CRVAL3 should be -5, CDELT3 -1
    #for Stokes   CRVAL3 should be  1, CDELT3  1
    #header['CRVAL3']  = -5.
    #header['CDELT3']  = -1.

    pol_typ = 1.  # FIXME
    #pol_typ =  Obs.pol_typ
    self.vis_header.update('CRPIX3', pol_typ)
    if pol_typ < 0:
      self.vis_header.update('CDELT3', -1.)
    else:
      self.vis_header.update('CDELT3', 1.)

    self.vis_header.update('CRPIX4', 1.)  # something .... n_freq/2 +1
    self.vis_header.update('CDELT4', v.config.bandwidth) # freq delta
    self.vis_header.update('CRVAL4', v.config.frequency) # center freq

    ra, dec = self.phase_center.radec(v.timestamp)

    self.vis_header.update('CRVAL5', ra.to_degrees())	  #SOURCE RA  PARAMETER
    self.vis_header.update('CRVAL6', dec.to_degrees())	#SOURCE DEC PARAMETER

    self.vis_header.add_history("AIPS WTSCAL =  1.0")  # has to be in here for some reason
    self.vis_header.add_comment("written by the TART UV FITS writer. ELEC Otago Uni")

  def update_ant_header(self):
    '''Update antenna header.'''

    v = self.v_array[0]

    self.ant_header.update('TFORM3', '1J')  #
    self.ant_header.update('TFORM4', '1J')    #
    self.ant_header.update('TFORM5', '1E')     #   replace (J,E,D) with (1J,1E,1D) to match difmap requirements
    self.ant_header.update('TFORM7', '1E')     # # ra and dec of sun here! FIXME - move to fixed phase center in ra/dec
    self.ant_header.update('TFORM10', '1E')   #
    self.ant_header.update('TFORM12', '1D') #

    self.ant_header.update('EXTNAME','AIPS AN')
    self.ant_header.update('XTENSION', 'BINTABLE')
    arr_loc = self.loc.get_ecef()
    self.ant_header.update('ARRAYX', arr_loc[0]) #
    self.ant_header.update('ARRAYY', arr_loc[1])  #  TART POSITION in ECEF coordinates
    self.ant_header.update('ARRAYZ', arr_loc[2]) #
    self.ant_header.update('FREQ', v.config.frequency)
    #/* GSTIAO is the GST at zero hours in the time system of TIMSYS (i.e. UTC) */
    #mjd = trunc(data->date[0] - 2400000.5);
    #temp = slaGmst(mjd)*180.0/M_PI;  # technically, slaGmst takes UT1, but it won't matter here.
    #fits_update_key(fptr,TDOUBLE,"GSTIA0",&temp , NULL, &status);
    self.ant_header.update('GSTIA0', self.loc.GST(v.timestamp).to_degrees())
    self.ant_header.update('DEGPDY', 3.60985642988E+02) # Rotation per day

    self.ant_header.update('RDATE', "%d-%02d-%02dT00:00:00.0"%(v.timestamp.year, v.timestamp.month, v.timestamp.day))
    self.ant_header.update('POLARX', 0.0)
    self.ant_header.update('POLARY', 0.0)
    self.ant_header.update('UT1UTC', 0.0)
    self.ant_header.update('DATUTC', 0.0)
    self.ant_header.update('TIMSYS', 'UTC')
    self.ant_header.update('ARRNAM', 'TART')
    self.ant_header.update('NUMORB', 0)
    self.ant_header.update('NOPCAL', 3)
    self.ant_header.update('FREQID', -1)
    self.ant_header.update('IATUTC', 33.0)
    self.ant_header.update('EXTVER', 1)
    #self.ant_header.update('XYZHAND','RIGHT')

  def write(self, filename):
    '''Generate tables and headers and write UVFITS file.'''
    vis_table = self.gen_vis_table()
    ant_table = self.gen_ant_table()

    self.vis_header = vis_table.header
    self.update_vis_header()
    self.ant_header = ant_table.header
    self.update_ant_header()

    hdulist = pyfits.hdu.hdulist.HDUList([vis_table, ant_table])
    hdulist.writeto(filename)
    print 'wrote %s' % filename
