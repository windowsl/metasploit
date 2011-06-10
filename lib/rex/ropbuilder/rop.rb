require 'metasm'
require 'rex/compat'
require 'rex/ui/text/table'
require 'rex/ui/text/output/stdio'
require 'rex/ui/text/color'

module Rex
module RopBuilder

class RopBase
	def initialize()
		@stdio = Rex::Ui::Text::Output::Stdio.new
		@gadgets = []
	end

	def to_csv(gadgets = [])
		if gadgets.empty? and @gadgets.nil? or @gadgets.empty?
			print_error("No gadgets collected to convert to CSV format.")
			return
		end

		# allow the users to import gadget collections from multiple files
		if @gadgets.empty? or @gadgets.nil?
			@gadgets = gadgets
		end

		table = Rex::Ui::Text::Table.new(
		'Header'    => "#{@file} ROP Gadgets",
		'Indent'    => 1,
		'Columns'   =>
		[
			"Address",
			"Raw",
			"Disassembly",
		])

		@gadgets.each do |gadget|
			table << [gadget[:address], gadget[:raw].unpack('H*')[0], gadget[:disasm].gsub(/\n/, ' | ')]
		end

		return table.to_csv
	end

	def import(file)
		begin
			data = File.new(file, 'r').read
		rescue
			print_error("Error reading #{file}")
		end

		data.gsub!(/\"/, '')
		data.gsub!("Address,Raw,Disassembly\n", '')
		@gadgets = []
		data.each_line do |line|
			addr, raw, disasm = line.split(',', 3)
			disasm.gsub!(/: /, ":\t")
			disasm.gsub!(' | ', "\n")
			raw = [raw].pack('H*')
			@gadgets << {:file => file, :address => addr, :raw => raw, :disasm => disasm.chomp!}
		end
			@gadgets
	end

	def print_msg(msg)
		if not @stdio
			@stdio = Rex::Ui::Text::Output::Stdio.new
		end

		@stdio.auto_color
		@stdio.print_raw(@stdio.substitute_colors(msg))
	end
end

class RopCollect < RopBase
	def initialize(file="")
		@file = file if not file.empty?
		@bin = Metasm::AutoExe.decode_file(file) if not file.empty?
		@disassembler = @bin.disassembler if not @bin.nil?
		super()
	end

	def collect(depth)
		rets = ["\xc3", "\xc2"] # ret, retn
		matches = []
		gadgets = []
		rets.each do |ret|
			# find matches by scanning for the pattern
			matches = @disassembler.pattern_scan(ret)

			if @bin.kind_of?(Metasm::PE)
				@bin.sections.each do |section|
					next if section.characteristics.include? 'MEM_EXECUTE'
					# delete matches if the address is outside the virtual address space
					matches.delete_if do |ea|
						va = section.virtaddr + @bin.optheader.image_base
						va <= ea and ea < va + section.virtsize
					end
				end
			elsif @bin.kind_of?(Metasm::ELF)
				@bin.segments.each  do |seg|
					next if seg.flags.include? 'X'
					matches.delete_if do |ea|
						ea >= seg.vaddr and ea < seg.vaddr + seg.memsz
					end
				end
			end
		end
		gadgets = self.process_gadgets(matches, depth)
		@gadgets = gadgets
		gadgets
	end

	def pattern_search(pattern)
		p = Regexp.new("(" + pattern + ")")
		matches = []
		@gadgets.each do |gadget|
			disasm = ""
			addrs = []

			gadget[:disasm].each_line do |line|
				addr, asm = line.split("\t", 2)
				addrs << addr
				disasm << asm
			end

			if gadget[:raw] =~ p or gadget[:disasm] =~ p or disasm =~ p
				matches << {:gadget => gadget, :disasm => disasm, :addrs => addrs}
			end
		end
		matches.each do |match|
			@stdio.print_status("gadget with address: %bld%cya#{match[:gadget][:address]}%clr matched")
			color_pattern(match[:gadget], match[:disasm], match[:addrs], p)
		end
		matches
	end

	def color_pattern(gadget, disasm, addrs, p)
		idx = disasm.index(p)
		if idx.nil?
			print_msg(gadget[:disasm])
			return
		end

		disasm = disasm.insert(idx, "%bld%grn")

		asm = ""
		cnt = 0
		colors = false
		disasm.each_line do |line|
			# if we find this then we are in the matching area
			if line.index(/\%bld\%grn/)
				colors = true
			end
			asm << "%clr" + addrs[cnt] + "\t"

			# color the remaining parts of the gadget
			if colors and line.index("%bld%grn").nil?
				asm << "%bld%grn" + line 
			else
				asm << line
			end

			cnt += 1
		end
		asm << "%clr\n"
		print_msg(asm)
	end

	def process_gadgets(rets, num)
		ret = {}
		gadgets = []
		rets.each do |ea|
			insn = @disassembler.disassemble_instruction(ea)
			next if not insn

			xtra = insn.bin_length

			1.upto(num) do |x|
				addr = ea - x

				# get the disassembled instruction at this address
				di = @disassembler.disassemble_instruction(addr)

				# skip invalid instructions
				next if not di
				next if di.opcode.props[:setip]
				next if di.opcode.props[:stopexec]

				# get raw bytes
				buf = @disassembler.read_raw_data(addr, x + xtra)

				# see if we have it already, if so, add the ea to the list
				arr = ret[buf]
				if arr
					arr << addr
					next
				end

				# make sure disassembling forward leads to our instruction
				next if not ends_with_addr(buf, addr, ea)
				dasm = ""
				while addr <= ea
					di = @disassembler.disassemble_instruction(addr)
					dasm << ("0x%08x:\t" % addr) + di.instruction.to_s + "\n"
					addr = addr + di.bin_length
				end
				# otherwise, we create a new tailchunk and add it to the list
				ret = {:file => @file, :address => ("0x%08x" % (ea - x)), :raw => buf, :disasm => dasm}
				gadgets << ret
			end
		end
		gadgets
	end

	private
	def ends_with_addr(raw, base, addr)
		dasm2 = Metasm::Shellcode.decode(raw, @disassembler.cpu).disassembler
		offset = 0
		while ((di = dasm2.disassemble_instruction(offset)))
			return true if (base + offset) == addr
			return false if di.opcode.props[:setip]
			return false if di.opcode.props[:stopexec]
			offset = di.next_addr
		end
		false
	end
end
end
end