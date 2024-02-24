import sys
import re

filename = sys.argv[1]
textfile = open(filename, 'r')
filetext = textfile.read()
textfile.close()
matches = re.findall("Waiting for Fernly USB loader \w+\.+ (\w+)", filetext)

binaryfile = open(filename+'.bin', 'wb')
binaryfile.write(bytes.fromhex(matches[0]))
binaryfile.close()
