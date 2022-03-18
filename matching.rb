#!/usr/bin/ruby
#!/usr/bin/env ruby

########################################
# require
########################################
require "optparse"


########################################
# constants
########################################
MAX_GRADE       = 5
MAX_PERFORMANCE = 5

########################################
# Array
########################################
class Array
  #### generate [n] ####
  def Array.idx(n)
    Array.new(n){|i| i}
  end

  #### generate a random permutation ####
  def Array.random_permutation(n)
    Array.idx(n).shuffle
  end

  #### generate a random probability vector ####
  def Array.random(n)
    Array.new(n){|_| rand()}.normalize
  end

  #### normalize : \sum_i self[i] = 1 ####
  def normalize
    sum = self.inject(:+)
    self.map{|e| e / sum.to_f}
  end

  def normalize!
    sum = self.inject(:+)
    self.map!{|e| e / sum.to_f}
  end

  #### argmax ####
  def argmax
    arg = nil
    self.size.times do |i|
      arg = i if arg.nil? or self[arg] < self[i]
    end
    return arg
  end

  #### argsort ####
  def argsort
    Array.new(self.size){|i| i}.sort_by{|i| self[i]}
  end

  #### indecies of the k biggest elements ####
  def top(k)
    self.argsort.reverse[0..k-1]
  end

  #### argminimal / argmaximal ####
  def argmaximal
    self.argXmal(+1){|i,j| yield(i,j)}
  end

  def argminimal
    self.argXmal(-1){|i,j| yield(i,j)}
  end

  def argXmal(sign)
    self.size.times do |i|
      # is self[i] maximal?
      is_maximal = true
      self.size.times do |j|
        if sign * yield(self[i], self[j]) < 0
          is_maximal = false
          break
        end
      end

      # self[i] is an maximal
      return i if is_maximal
    end
    nil
  end

  #### destructive method : find a total order by yield ####
  def total_sort
    # init
    cmp = Array.new(self.size){|i| Array.new(self.size){|j| yield(self[i],self[j])}}
    ary = self.clone
    sorted = []

    while ary.size > 0
      #### find argminimal ####
      arg = nil
      ary.size.times do |i|
        if cmp[i].find{|c| c > 0}.nil?
          arg = i
          break
        end
      end
      return nil if arg.nil?

      #### update ####
      ele = ary.delete_at(arg)
      cmp.map{|row| row.delete_at(arg)}
      cmp.delete_at(arg)
      sorted.push(ele)
    end
    sorted
  end
end


########################################
# Preference: list of preferred elements
########################################
class Preference
  #### generate a random preference on [n] ####
  def Preference.random(n)
    Preference.new(Array.random_permutation(n))
  end

  #### generate a permutation by importance values ####
  def Preference.by_importance(vals)
    Preference.new(vals.argsort.reverse)
  end

  #### generate a preference with list array ####
  def initialize(ary)
    @ary = ary
  end
  attr_reader :ary

  #### size ####
  def size
    @ary.size
  end

  #### self[i]: the i-th ranked element ####
  def [](i)
    @ary[i]
  end

  #### last element ####
  def last
    @ary.last
  end

  #### rank of i ####
  def rank(i)
    @ary.find_index{|j| i == j}
  end

  #### prefer : rank(i) < rank(j) ? ####
  def prefer_to(i, j)
    ri = self.rank(i)
    rj = self.rank(j)
    ri.nil? ? false : (rj.nil? ? true : (self.rank(i) < self.rank(j)))
  end

  #### ranks of elements in ary ####
  def ranks(ary = @ary)
    ary.map{|i| self.rank(i)}
  end

  #### the worst rank in ary ####
  def worst_element(ary = @ary)
    ary[ self.worst_index(ary) ]
  end

  #### the worst element in ary ####
  def worst_index(ary = @ary)
    ranks = self.ranks(ary)
    worst = ranks.max
    ranks.find_index{|r| r == worst}
  end

  #### def ####
  def to_string
    @ary.join(">")
  end

  #### show ####
  def show
    puts "#{self.to_string} (#{@ary.size})"
  end
end


########################################
# Matching
########################################
class Matching
  #### new ####
  def initialize(n0, n1)
    # @n[s] = # of object in Side s
    @num = [n0, n1]

    # @partners[s][i] = partners of object i in Side s
    @partners = [Array.new(@num[0]){|i| Array.new},
                 Array.new(@num[1]){|i| Array.new}]
  end

  #### accessors ####
  attr_reader :num, :partners

  #### size = # of matches ####
  def size
    count = 0
    @num[0].times do |i|
      @num[1].times do |j|
        count += 1 if match?(i, j)
      end
    end
    count
  end

  #### match? ####
  def match?(i0, i1)
    @partners[0][i0].include?(i1) # <=> @partners[1][i1].include?(i1)
  end

  #### match ####
  def match(i0, i1)
    if !self.match?(i0, i1)
      @partners[0][i0].push(i1)
      @partners[1][i1].push(i0)
    end
  end

  #### unmatch ####
  def unmatch(i0, i1)
    if self.match?(i0, i1)
      @partners[0][i0].delete(i1)
      @partners[1][i1].delete(i0)
    end
  end

  #### show ####
  def show
    2.times do |s|
      puts "<<<< Side #{s} >>>>"
      @num[s].times do |i|
        puts "#{i} : #{@partners[s][i]}" if !@partners[s][i].empty?
      end
    end
  end

  ########################################
  # DA algorithm
  # cap[s][i] : capacity of i in side s
  # prf[s][i] : preference of i in side s
  ########################################
  def Matching.DAalgorithm(cap, prf, show: false)
    puts "<<<< DA algorithm >>>>" if show

    # generate an empty matching
    num = [prf[0].size, prf[1].size]
    mat = Matching.new(*num)

    # k = prop[i]: student s will propose to the k-th candidate next
    prop = Array.new(num[0], 0)

    # DA algorithm
    while true
      #### find the next pair (i, j); break if no such pair ####
      pair = nil
      num[0].times do |i|
        # skip if i has no capacity
        next if mat.partners[0][i].size == cap[0][i]

        # skip if i has no more candidate
        next if prop[i] == prf[0][i].size

        # (i, j) is an appropriate pair
        k = prop[i]
        j = prf[0][i][k]
        pair = [i, j]
        break
      end
      break if pair.nil?

      #### i proposes to j ####
      i, j = pair
      prop[i] += 1
      puts "student #{i} proposes to course #{j}" if show

      # j has a vacant seat -> j accepts i
      if mat.partners[1][j].size < cap[1][j]
        mat.match(i, j)
        puts "> accepted" if show

      # j has no vacant seat
      else
        # w: the current worst partner of j in side 1
        w = prf[1][j].worst_element( mat.partners[1][j] )

        # j prefers i to w -> j rejects w then accepts i
        if prf[1][j].prefer_to(i, w)
          mat.unmatch(w, j)
          mat.match(i, j)
          puts "> accepted but rejected #{w} instead" if show

        # otherwise -> j rejects i
        else
          puts "> rejected" if show
        end
      end
    end

    # return matching
    mat
  end
end


########################################
# Course
########################################
class Course
  #### class variable/method ####
  @@num_courses = 0

  #### new ####
  def initialize(category, difficulty)
    @id = @@num_courses
    @category    = category
    @difficalty  = difficulty
    @requirement = Array.new
    @reference   = Array.new
    @@num_courses += 1
  end

  #### accessors ####
  attr_reader :id, :category, :difficalty, :requirement, :reference

  #### add id as a requirement ####
  def add_requirement(id)
    @requirement.push(id)
    @reference.push(id)
  end

  #### add id as a reference ####
  def add_reference(id)
    @reference.push(id)
  end

  #### eligibility of student with gp
  def eligibility(performance)
    return 0 if performance[@id] > 0
    return 1 if @requirement.empty?
    return 0 if @requirement.map{|j| performance[j]}.min == 0
    return @reference.map{|j| performance[j]}.max
  end

  #### show ####
  def show
    puts "#{@id}, #{@category}, #{@difficulty}, #{@requirement}, #{@reference}"
  end
end


########################################
# Student
########################################
class Student
  #### class variable/mathod ####
  @@num_students = 0

  #### a starter student with random interest ####
  def Student.random(crs_ary)
    m = crs_ary.size
    s = Student.new(0, Array.new(m, 0), Array.random(m))
    s.update_current_interest(crs_ary)
    s
  end

  #### a student ####
  def initialize(grade = 0, peformance = nil, interest = nil)
    @id = @@num_students
    @grade       = grade
    @performance = peformance
    @interest    = interest
    @current_interest = nil
    @@num_students += 1
  end

  #### accessors ####
  attr_reader :id, :grade, :performance, :interest, :current_interest

  #### eligible course list ####
  def eligible_course_list(crs_ary)
    Array.idx(crs_ary.size).select{|j| crs_ary[j].eligibility(@performance) > 0}
  end

  #### top-k course list ####
  def topk_course_list(crs_ary, k)
    ecl = self.eligible_course_list(crs_ary)
    ecl.map{|j| @interest[j]}.top(k).map{|i| ecl[i]}
  end

  #### update the current interest according to the true interest ####
  def update_current_interest(crs_ary)
    @current_interest = Array.new(crs_ary.size, 0)
    self.eligible_course_list(crs_ary).each do |j|
      @current_interest[j] = @interest[j]
    end
    @current_interest.normalize!
  end

  #### update the current interest by list approximation ####
  def update_current_interest_by_list(crs_ary, k)
    # get top-k list
    topk = self.topk_course_list(crs_ary, k)

    # approximate by top-k list
    @current_interest = Array.new(crs_ary.size, 0)
    topk.size.times do |i|
      @current_interest[ topk[i] ] = k - i + 1
    end
    @current_interest.normalize!
  end

  #### update the current interest by point approximation ####
  def update_current_interest_by_point(crs_ary, k)
    #### get point ####
    top = self.topk_course_list(crs_ary, k)
    return nil if top.size == 0

    int = top.map{|j| @interest[j]}
    pnt = Array.new(k, 0)
    sum = int.inject(:+)

    while k * int[-1] < sum
      top.pop
      sum -= int.pop
      pnt.pop
    end
    unit = sum / k.to_f

    k.times do |_|
      l = int.argmax
      int[l] -= unit
      pnt[l] += 1
    end

    #### approximate by point ####
    @current_interest = Array.new(crs_ary.size, 0)
    top.size.times do |l|
      @current_interest[ top[l] ] = pnt[l]
    end
    @current_interest.normalize!
  end

  #### take k most interested courses ####
  def take_courses(crs_ary, k)
    self.topk_course_list(crs_ary, k).each do |j|
      @performance[j] = rand(1..MAX_PERFORMANCE)
    end
    self.update_current_interest(crs_ary)
    @grade += 1
  end

  #### show ####
  def show
    puts "Student #{@id} @ #{@grade}"
    @performance.size.times do |j|
      puts "#{j} : #{@performance[j]}, #{@interest[j]}, #{@current_interest[j]}"
    end
  end
end


########################################
# School
########################################
class School
  #### school with students ss and courses cs ####
  def initialize(std_ary, crs_ary, std_cap, crs_cap)
    # # of students & courses
    @std_num = std_ary.size
    @crs_num = crs_ary.size

    # arys of students & courses
    @std_ary = std_ary
    @crs_ary = crs_ary

    # capacities of students & courses
    @std_cap, @crs_cap = [Array.new(@std_num, std_cap), Array.new(@crs_num, crs_cap)]

    # true preference
    @std_prf, @crs_prf = self.current_preferences
  end
  attr_reader :std_num, :crs_num, :std_ary, :crs_ary, :std_cap, :crs_cap

  #### school with random students and courses ####
  # std_num: # students of each grade level
  # cat_num; # categories
  # std_cap: capacity of each student
  # crs_cap: capacity of each course
  def School.random(std_num, cat_num, std_cap, crs_cap)
    #### # courses = num_categories * 5 (1 cat = 2 base, 2 adv, and 1 mix) ####
    crs_ary = []
    cat_num.times do |l|
      #### two base ####
      b1 = Course.new(l, 0)
      b2 = Course.new(l, 0)
      crs_ary.push(b1)
      crs_ary.push(b2)

      #### two advance ####
      a1 = Course.new(l, 1)
      a2 = Course.new(l, 1)
      a1.add_requirement(b1.id)
      a2.add_requirement(b2.id)
      crs_ary.push(a1)
      crs_ary.push(a2)

      #### one mix ####
      mx = Course.new(l, 3)
      mx.add_requirement(b1.id)
      mx.add_requirement(b2.id)
      mx.add_reference(a1.id)
      mx.add_reference(a2.id)
      crs_ary.push(mx)
    end

    #### # students = L * num_students ####
    std_ary = []
    MAX_GRADE.times do |l|
      std_num.times do |_|
        s = Student.random(crs_ary)
        l.times{|__| s.take_courses(crs_ary, crs_cap)}
        std_ary.push(s)
      end
    end

    #### return ####
    School.new(std_ary, crs_ary, std_cap, crs_cap)
  end

  #### current interest of i in j ####
  def current_interest(i, j)
    @std_ary[i].current_interest[j]
  end

  #### eligibility of student i for course j ####
  def eligibility(i, j)
    @crs_ary[j].eligibility(@std_ary[i].performance)
  end

  #### eligible coures & students ####
  def eligible_courses(i)
    Array.idx(@crs_num).select{|j| self.eligibility(i, j) > 0 }
  end

  def eligible_students(j)
    Array.idx(@std_num).select{|i| self.eligibility(i, j) > 0 }
  end

  #### the current preference of student i ####
  def current_student_preference(i)
    Preference.new( self.eligible_courses(i).total_sort{|j1, j2| -self.comp_courses(i, j1, j2)} )
  end

  #### the current preference of course j ####
  def current_course_preference(j)
    Preference.new( self.eligible_students(j).total_sort{|i1, i2| -self.comp_students(j, i1, i2)} )
  end

  #### compare courses j1 and j2 by the preference of student i ####
  # j1 \pref_i j2 -> +1
  # j2 \pref_i j1 -> -1
  # otherwise -> 0
  def comp_courses(i, j1, j2)
    # for dumy
    return 0  if j1 == -1 and j2 == -1
    return -1 if j1 == -1
    return +1 if j2 == -1

    # eligibility
    e1 = self.eligibility(i, j1)
    e2 = self.eligibility(i, j2)

    # current interests
    c1 = self.current_interest(i, j1)
    c2 = self.current_interest(i, j2)

    return 0  if e1 == 0 and e2 == 0
    return -1 if e1 == 0
    return +1 if e2 == 0
    return -1 if c1 < c2
    return +1 if c1 > c2
    return 0
  end

  #### compare students i1 and i2 by the preference of course j ####
  # i1 \pref_j i2 -> +1
  # i2 \pref_j i1 -> -1
  # otherwise -> 0
  def comp_students(j, i1, i2)
    # for dumy
    return 0  if i1 == -1 and i2 == -1
    return -1 if i1 == -1
    return +1 if i2 == -1

    # grade level
    g1 = @std_ary[i1].grade
    g2 = @std_ary[i2].grade

    # eligibility
    e1 = self.eligibility(i1, j)
    e2 = self.eligibility(i2, j)

    # current interest
    c1 = self.current_interest(i1, j)
    c2 = self.current_interest(i2, j)

    return -1 if g1 < g2
    return +1 if g1 > g2
    return -1 if e1 <= e2 and c1 < c2
    return +1 if e1 >= e2 and c1 > c2
    return 0
  end

  #### current preference ####
  def current_preferences
    [Array.new(@std_num){|i| self.current_student_preference(i)},
     Array.new(@crs_num){|j| self.current_course_preference(j)}]
  end

  #### update current interest by true intereset ####
  def update_current_interest
    @std_ary.each do |s|
      s.update_current_interest(@crs_ary)
    end
  end

  #### update current interest by top-k list ####
  def update_current_interest_by_list(k)
    @std_ary.each do |s|
      s.update_current_interest_by_list(@crs_ary, k)
    end
  end

  #### update current interest by k point ####
  def update_current_interest_by_point(k)
    @std_ary.each do |s|
      s.update_current_interest_by_point(@crs_ary, k)
    end
  end

  #### allocation ####
  def allocate
    cap = [@std_cap, @crs_cap]
    prf = [@std_prf, @crs_prf]
    mat = Matching.DAalgorithm(cap, prf)
  end

  def allocate_by_list(k)
    self.update_current_interest_by_list(k)
    cap = [@std_cap, @crs_cap]
    prf = self.current_preferences
    mat = Matching.DAalgorithm(cap, prf)
  end

  def allocate_by_point(k)
    self.update_current_interest_by_point(k)
    cap = [@std_cap, @crs_cap]
    prf = self.current_preferences
    mat = Matching.DAalgorithm(cap, prf)
  end

  #### evaluate matching mat ####
  def evaluate(mat)
    #### update current interest by true interest ####
    self.update_current_interest

    #### last elements in m ####
    std_last = Array.idx(@std_num).map{ |i|
      mat.partners[0][i].size < @std_cap[i] ? -1 : mat.partners[0][i].max_by{|j| @std_prf[i].rank(j)}
    }

    crs_last = Array.idx(@crs_num).map{ |j|
      mat.partners[1][j].size < @crs_cap[j] ? -1 : mat.partners[1][j].max_by{|i| @crs_prf[j].rank(i)}
    }

    #### count blocking pairs ####
    cnt = 0
    @std_num.times do |i|
      @std_prf[i].ary.each do |j|
        next if mat.match?(i, j)
        cnt += 1 if self.comp_courses(i, j, std_last[i]) > 0 and self.comp_students(j, i, crs_last[j]) > 0
      end
    end

    #### average # match & score ####
    num = 0
    sum = 0
    @std_num.times do |i|
      mat.partners[0][i].each do |j|
        sum += @std_ary[i].current_interest[j]
        num += 1
      end
    end
    num /= @std_num.to_f
    sum /= @std_num.to_f 

    #### return ####
    [cnt, num, sum]
  end

  #### show ####
  def show
    puts "<<<< #{@std_num} Students >>>>"
    @std_ary.each do |s|
      s.show
    end

    puts "<<<< #{@crs_num} Courses >>>>"
    @crs_ary.each do |c|
      c.show
    end
  end
end


########################################
# default values
#############################P###########
@seed = Random.new_seed
@num = [20, 20] #std_num, crs_num#
@cap = [10, 10] #std_cap, crs_cap#
@maxk = 20
@mode = 1
@show = false
@body = nil


########################################
# Arguments
########################################
OptionParser.new { |opts|
  # options
  opts.on("-h","--help","Show this message") {
    puts opts
    exit
  }
  opts.on("--seed [int]", "random seed") { |f|
    @seed = f.to_i
  }
  opts.on("--std-num [int]", "# stduents in each grade"){ |f|
    @num[0] = f.to_i
  }
  opts.on("--cat-num [int]", "# categories"){ |f|
    @num[1] = f.to_i
  }
  opts.on("--std-cap [int]", "capacity of each student"){ |f|
    @cap[0] = f.to_i
  }
  opts.on("--crs-cap [int]", "capacity of each course"){ |f|
    @cap[1] = f.to_i
  }
  opts.on("--maxk [int]", "maximum of k"){ |f|
    @maxk = f.to_i
  }
  opts.on("--body [string]", "output header to body.txt & results to body.csv"){ |f|
    @body = f
  }
  opts.on("--show", "Show the process of matching") {
    @show = true
  }

  # parse
  opts.parse!(ARGV)
}

########################################
# main
########################################

#### generate problem & stable matching ####
srand(@seed)
s = School.random(*@num, *@cap)
mat = s.allocate
cnt, num, sum = s.evaluate(mat)

#### Header ####
f = STDOUT
if @body.nil?
  f.puts "#### Header ####"
else
  f = open("#{@body}.txt", "w")
end
f.puts "seed    = #{@seed}"
f.puts "std_num = #{s.std_num}"
f.puts "crs_num = #{s.crs_num}"
f.puts "std_cap = #{s.std_cap.first}"
f.puts "crs_cap = #{s.crs_cap.first}"
f.puts "max k   = #{@maxk}"
f.puts "|M|     = #{mat.size}"
f.puts "cnt     = #{cnt}"
f.puts "num     = #{num}"
f.puts "sum     = #{sum}"
f.close if !@body.nil?

#### Results ####
if @body.nil?
  f.puts "#### Results ####"
  f.puts "k, {|M|, |B|, ave # matching, ave score} x {exact, list, point}"
else
  f = open("#{@body}.csv", "w")
end

# for k in 1..@maxk
k = 5 
while k <= @maxk
  # list
  lmat = s.allocate_by_list(k)
  lcnt, lnum, lsum = s.evaluate(lmat)

  # point
  pmat = s.allocate_by_point(k)
  pcnt, pnum, psum = s.evaluate(pmat)

  # results
  f.puts "#{k}, #{mat.size}, #{lmat.size}, #{pmat.size}, #{cnt}, #{lcnt}, #{pcnt}, #{num}, #{lnum}, #{pnum}, #{sum}, #{lsum}, #{psum}"

  k += 5
end
f.close if !@body.nil?
