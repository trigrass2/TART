import spi

import numpy as np
import time
import argparse

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Test bench for TART commuication via SPI.')
  parser.add_argument('--speed', default=8, type=int, help='Specify the SPI CLK speed (in MHz)')
  parser.add_argument('--bramexp', default=9, type=int, help='exponent of bram depth')
  parser.add_argument('--debug', action='store_true', help='print debug output to screen')
  parser.add_argument('--fast', action='store_true', help='use faster transfer!')
 
  args = parser.parse_args()
  spi.openSPI(speed=args.speed*1000000)
  time.sleep(0.1)
  
  # START AQUSITION BY SETTING REG[0001] to 1
  print spi.transfer((0b10000001,0x1))
  
  time.sleep(0.3)
  resp = []
  
  num_bytes = np.power(2,args.bramexp)
  if (args.bramexp>10):
    num_bytes = num_bytes-32
 
  print 'receiving 3x', num_bytes
  
  blocksize = 1000
  if (args.fast):
    resp2 = []
    for i in range(0,int(num_bytes/blocksize)):
      resp2.append(spi.transfer((0b00000010,) + (0,0,0,)*blocksize)[1:])
    resp3 = spi.transfer((0b00000010,) + (0,0,0,)*(num_bytes%blocksize))[1:]
  
  else:
    for i in range(num_bytes):
      resp.append(spi.transfer((0b0000010,0x0,0x0,0x0))[1:])
  
  print 'got data..' 
  
  
  if args.debug:
    ant_data = [] 
    if (args.fast):
      print 'reshape data blocks'
      resp2 = np.array(resp2,dtype=int).reshape(-1,3)
      print 'reshape data remainder'
      resp3 = np.array(resp3,dtype=int).reshape(-1,3)
      print 'concatenate...'
      resp2 = np.concatenate((resp2,resp3))
      print 'generate 24bit integer'
      resp_dec = (resp2[:,0] << 16) + (resp2[:,1] << 8) + resp2[:,2]
      print 'done'
  
      print 'shift into seperate antenna arrays' 
      for i in range(8):
         ant_data.append(np.array((resp2[:,2] & 1<<(i))>0,dtype=int))

      for i in range(8):
         ant_data.append(np.array((resp2[:,1] & 1<<(i))>0,dtype=int))
      
      for i in range(8):
         ant_data.append(np.array((resp2[:,0] & 1<<(i))>0,dtype=int))
      
      print 'antdata0', ant_data[0]
      print 'antdata1', ant_data[1]

    else:
      resp = np.array(resp)
      resp_dec = (resp[:,0] << 16) + (resp[:,1] << 8) + resp[:,2]
    #resp_bin = np.array([[np.binary_repr(i,8) for i in j] for j in resp])
    #resp_hex = np.array([[hex(i) for i in j] for j in resp])
    #for i, ent in enumerate(resp_dec):
    #  print i, ent, resp_bin[i], resp_hex[i]
    print (resp_dec[1:]-resp_dec[:-1])
    print (resp_dec[1:]-resp_dec[:-1]).__ne__(1).sum()
  
  '''
  resp = []
  for i in range(num_bytes):
    resp.append(spi.transfer((0b00000100,0x0))[1:])
  
  resp = np.array(resp)
  resp_bin = [[np.binary_repr(i,8) for i in j] for j in resp]
  resp_hex = [[hex(i) for i in j] for j in resp]
  for i in range(len(resp)/10):
    j = i*10
    print [resp[j+k] for k in range(10)]
  print resp_bin, resp_hex
  #'''

