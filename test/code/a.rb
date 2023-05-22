# An example class.
#
# = H1
# == H2
# === H3
# ==== H4
# ===== H5
# ====== H6
#
# - Links to headers:
#
#   - A@H1.
#   - A@H2.
#   - A@H3.
#   - A@H4.
#   - A@H5.
#   - A@H6.
#
# - Link to class:  A.
# - Link to constant: ConstantA.
# - Link to accessor: #accessor_a.
# - Link to reader: #reader_a.
# - Link to writer: #writer_a.
# - Link to instance method: #instance_method_a.
# - Link to instance alias: #instance_alias_a.
# - Link to singleton method: ::singleton_method_a.
# - Link to singleton alias: ::singleton_alias_a.
# - Link to URL: https://docs.ruby-lang.org/en/master/Array.html.
#
# - Link to bad URL: https://nosuch.xyzzy.
# - Link to bad fragment: https://docs.ruby-lang.org/en/master/Array.html#xyzzy.
#
class A

  attr_accessor :accessor_a
  attr_reader :reader_a
  attr_writer :writer_a

  ConstantA = 'A'

  def initialize
  end

  def self.singleton_method_a
  end

  def instance_method_a
  end
  alias instance_alias_a instance_method_a

end