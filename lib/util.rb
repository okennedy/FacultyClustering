class Tokenizer
  def initialize(string, token, input_source = nil)
    @tokens = string.scan(token);
    @last = nil;
    @input_source = input_source;
    @string = string;
  end
  
  def scan
    while @tokens.size > 0
      if !(yield @tokens.shift) then break; end
    end
  end
  
  def peek
    if @tokens.size > 0 then @tokens[0]
    else nil; end
  end
  
  def next
    @last = 
      if @tokens.size > 0 then @tokens.shift
      else nil; end
  end
  
  def last
    @last;
  end
  
  def more?
    @tokens.size > 0;
  end
  
  def flatten
    @tokens = @tokens.flatten;
  end
  
  def assert_next(token, errstr = nil)
    case token
      when String then raise_error(errstr || "Expected '#{token}' but found '#{last}'") unless self.next == token
      when Array  then raise_error(errstr || "Expected '#{token.join("','")}' but found '#{last}'") unless token.include? self.next;
    end
    self.last;
  end
  
  def raise_error(errstr);
    errstr = "#{errstr} (line #{@input_source.lineno})" if @input_source;
    errstr = "#{errstr} (#{@string})" unless @input_source;
    raise "Parse Error: #{errstr}";
  end
  
  def tokens_up_to(token)
    ret = Array.new;
    while (more? && (self.next != token))
      ret.push(last);
    end
    ret;
  end
end

class Array
  def map_index
    (0...length).to_a.map { |i| yield(i, self[i]) }
  end

  def to_h
    ret = Hash.new;
    each { |k,v| ret[k] = v; }
    return ret;
  end

  def unzip
    ret = Array.new;
    each_index do |i|
      ret.push Array.new(i) while ret.length < self[i].length
      ret.each_index do |j|
        ret[j][i] = self[i][j]
      end
    end
    return ret;
  end

  def count
    size
  end

  def sum
    ret = 0;
    each { |item| ret += item }
    return ret;
  end

  def avg
    sum.to_f / length.to_f
  end

  def prod
    ret = 1;
    each { |item| ret *= item }
    return ret;
  end

  def rms_avg
    Math.sqrt(map { |x| x.to_f ** 2 }.avg)
  end

  def rms_err
    Math.sqrt(map { |x,y| (x.to_f - y.to_f) ** 2 }.avg)
  end

  def stddev
    Math.sqrt((avg ** 2 - (map{|i| i.to_f ** 2}.avg)).abs)
  end
  
  def reduce(&reducer)
    ret = Hash.new;
    each do |k,v|
      ret[k] = Array.new unless ret.has_key? k;
      ret[k].push(v);
    end
    if reducer.nil? then ret
    else
      ret.to_a.collect do |k,vs|
        [ k, reducer.call(k, vs) ]
      end.to_h
    end
  end
  
  # Round-robin partition into K arrays
  def subdivide(k)
    cnt = 0;
    ret = (0...k).map {|i| Array.new };
    each { |i| ret[cnt % k].push i; cnt += 1; };
    ret;
  end
  
  # Inorder partition into groups of K elements
  def take_groups(k)
    (0...(size / k.to_f).ceil).map do |i|
      self[k*i...[k*(i+1), size].min] 
    end
  end
  
  def zip_members
    self[0].zip(*(self[1..-1]))
  end
  
  def grep(pattern, &block)
    ret = [];
    if block.nil? 
    then each { |l| ret.push(l) if pattern =~ l; }
    else each { |l| match = pattern.match(l);
                    ret.push(block.call(match)) if match; }
    end
    ret
  end
  
  def window(window_size = 10, &block)
    if length <= window_size then 
      if block.nil? then return [self.clone];
                    else return [block.call(self)];
      end
    else
      ret = Array.new;
      w = Array.new;
      each do |item|
        w.push(item);
        w.shift if w.length > window_size;
        if w.length >= window_size then
          ret.push(if block.nil? then [w.clone] else block.call(w) end)
        end
      end
      ret
    end
  end
  
  def fold(accum = nil)
    each { |i| accum = yield accum, i }
    accum
  end
  
  def pick_samples_evenly(num_samples)
    return self if(self.length <= num_samples);
    keep_steps = (self.length / num_samples).to_i
    step = 0;
    self.delete_if { step += 1; (step % keep_step) == 0 }
  end
  
  def to_table(headers = nil)
    row_sizes = 
      ((headers.nil? ? [] : [headers]) + self).
        map { |row| row.map { |c| c.to_s.length } }.
        unzip.
        map { |col| col.compact.max }
    
    ( unless headers.nil? then
        [ " " + headers.zip(row_sizes).map do |col, exp_size|
            col.center(exp_size)
          end.join(" | "), 
          ("-" * (row_sizes.sum + 2 + (row_sizes.length - 1) * 3))
        ]
      else [] end + 
      map do |row|
        " " + row.zip(row_sizes).map do |col, exp_size|
          col = col.to_s
          if col.size < exp_size 
            then col.center(exp_size)
            else col
          end
        end.join(" | ")
      end
    ).join("\n")
  end

  def tabulate_schemaless_records
    keys = map {|r| r.keys}.flatten.unique.sort

    [ keys , 
      map {|r| keys.map {|k| r[k] }}
    ]
  end
  
  def for_all
    each { |v| return false unless yield v }
    true;
  end
  
  def each_prefix
    each_index do |i|
      yield self[0..i];
    end
  end
  
  def select
    map { |x| x if yield x }.compact
  end
  
  def cogroup
    ret = Hash.new { |h,k| h[k] = [nil] * size }
    each_index do |i|
      self[i].each do |k, v|
        ret[k][i] = v
      end
    end
    ret
  end
  
  # Return every cnt'th element of the array.
  def every(cnt, start = 0)
    (0..(((size-1-start)/cnt).to_i)).map { |i| self[i*cnt+start] }
  end
  
  # Create batches of up to size cnt.
  def batch(cnt)
    (0..(((size-1)/cnt).to_i)).map { |i| self[(i*cnt)...((i+1)*cnt)] }
  end

  def flatmap
    ret = []
    each { |i| ret = ret + yield(i) }
    ret
  end
  
  def project(*keys)
    map { |x| x.project(*keys) }
  end
  
  def unique
    last = nil
    sort.
      map { |c| last = c if c != last }.
#      map { |c| p c }.
      compact
  end
  
  def histogram(bin_width = 5)
    min_val = (min - min % bin_width).to_i
    max_val = (max - max % bin_width + bin_width).to_i
    
    (min_val..max_val).to_a.every(bin_width).
      map { |x| [x, 0] }.
      to_h.
      join(map { |x| (x.to_f / bin_width).to_i * bin_width }.
             reduce { |k,v| v.count },
             :left
          ).
      map { |bin, cnt| [bin, cnt.compact.sum] }.
      sort { |a, b| a[0] <=> b[0] }
  end

  def cumulative_sum
    tot = 0;
    map { |x| tot += x }
  end

  def splice(val, idx)
    return [val] + self if idx <= 0
    return self + [val] if idx >= length
    return self[0...idx] + [val] + self[idx..-1]
  end

  def all_sorts
    return [[]] if empty? 
    return [self] if length == 1
    hd = self[0]
    self[1..-1].all_sorts.map do |rest|
      (0..rest.length).map { |i| rest.splice(hd, i) }
    end.flatten(1)
  end

  def merge(other, args = {})
    if args.has_key?(:eq)
      args[:eq] = [args[:eq], args[:eq]] unless args[:eq].is_a? Array
      a, b = args[:eq]
      idx = Hash.new { |h,k| h[k] = [] }
      self.each {|i| idx[i[a]].push i }
      other.map {|j| idx[i[b]].map { |i| i + j } }.flatten(1)
    else
      self.map {|i| 
        other.map {|j| 
          i + j if yield i,j
        }.compact
      }.flatten(1)
    end
  end

  def where
    map {|i| i if yield i }.compact
  end
end

class Hash
  def intersect(other)
    keys.find_all { |k| other.has_key?(k) }
  end

  def bar_graph_dataset(bar = 0.5, set_sep = 1.0, bar_sep = 0.2)
    curr_width = 0;
    tics = collect do |human,data|
      next_delta = data.length * bar + (data.length - 1) * bar_sep;
      curr_width += next_delta + set_sep;
      "\"#{human}\" #{curr_width - next_delta / 2}"
    end

    curr_width = 0;
    points = values.collect do |data|
      curr_width += set_sep - bar_sep
      data.collect do |point|
        curr_width += bar_sep + bar;
        [curr_width - bar / 2, point]
      end
    end.unzip;

    return ["(#{tics.join(', ')})" , points, "[0:#{curr_width+set_sep}]"];
  end
  
  def to_sorted_a
    keys.sort.map do |k|
      [k, self[k]]
    end
  end
  
  def map_leaves(prefix = [])
    keys.to_a.map do |k| 
      [ k, 
        if self[k].is_a? Hash
          then self[k].map_leaves(prefix+[k]) { |ik,v| yield(ik, v) }
          else yield(prefix+[k], v)
        end
      ]
    end.to_h
  end

  def project(*keys)
    keys.map { |k| self[k] }
  end
  
  def join(h, outer = :no)
    case outer
      when :full then
        keys + h.keys.find_all { |k| not has_key? k }
      when :left then
        keys
      when :right then
        h.keys
      else 
        intersect(h) 
    end.
    map { |k| [k, [self[k], h[k]]] }.to_h
  end

  def flatten_tree(sep = nil, prefix = nil)
    map { |k,v|
      unless prefix.nil? 
        k = sep + k.to_s unless sep.nil?
        k = prefix.to_s + k.to_s
      end
      case v
      when Hash then v.flatten_tree(sep, k).to_a
      else [ [k.to_sym, v] ]
      end
    }.flatten(1).to_h
  end
end

class Float
  def sig_figs(n)
    if self == 0.0 then self
    else
      mult = (10.0 ** (Math.log10(self).ceil.to_f - n.to_i.to_f))
      (self / mult).round * mult;
    end
  end
end

class IO
  def tee_readlines
    ret = [];
    each { |l| yield l; ret.push l }
    ret
  end
  
  def grep
    map {|x| x if yield x}.compact
  end
end

class File
  def File.stream(inFile, outFile, mode = "w+")
    File.open(inFile) do |inHandle|
      File.open(outFile, mode) do |outHandle|
        yield(inHandle, outHandle)
      end
    end
  end
end

class Integer
  def to_bytestring
    return "-#{(-self).to_bytestring}" if self < 0;
    depth = (Math.log(self/2) / (10.0 * Math.log(2))).to_i
    scales = ["B", "KB", "MB", "GB", "PB", "EB"];
    depth = scales.length-1 if depth >= scales.length;
    "#{(self.to_f / (1024.0**(depth))).to_f.sig_figs(4)} #{scales[depth]}"
  end
  
  def d(die)
    (0...self).map { rand(die)+1 }
  end
end

class String
  def pluralize(num)
    if num == 1 then self
    else self+"s"
    end
  end
end

class Dir
  def Dir.in_dir(d)
    old_d = Dir.getwd
    Dir.chdir d
    ret = yield
    Dir.chdir old_d
    ret
  end
end

