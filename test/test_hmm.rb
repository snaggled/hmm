require './helper'
require 'narray'

class TestHmm < Test::Unit::TestCase
	def setup
		@simple_model = HMM::Classifier.new
		
		# manually build a classifier
        #@simple_model.debug = True
		@simple_model.o_lex = ["A", "B"]
		@simple_model.q_lex = ["X", "Y", "Z"]
		@simple_model.a = NArray[[0.8, 0.1, 0.1],
					[0.2, 0.5, 0.3],
					[0.9, 0.1, 0.0]].transpose(1,0)
		@simple_model.b = NArray[ [0.2, 0.8],
					[0.7, 0.3],
					[0.9, 0.1]].transpose(1,0)
		@simple_model.pi = NArray[0.5, 0.3, 0.2]

	end
	
	should "create new classifier" do
		model = HMM::Classifier.new
		assert model.class == HMM::Classifier
	end

    should "train" do
		a = HMM::Classifier.new
        a.add_to_train(['a', 'b', 'c', 'd', 'e'], ['A', 'B', 'C', 'D', 'E'])
        a.add_to_train(['a', 'b', 'c', 'c', 'e'], ['A', 'B', 'C', 'C', 'E'])
        a.add_to_train(['a', 'b', 'd', 'd', 'e'], ['A', 'B', 'D', 'D', 'E'])
        a.train()

		b = HMM::Classifier.new
        b.add_to_train(['a', 'b', 'c', 'd', 'f'], ['A', 'B', 'C', 'D', 'F'])
        b.add_to_train(['a', 'b', 'c', 'c', 'f'], ['A', 'B', 'C', 'C', 'F'])
        b.add_to_train(['a', 'b', 'c', 'b', 'f'], ['A', 'B', 'C', 'B', 'F'])
        b.add_to_train(['a', 'b', 'c', 'a', 'f'], ['A', 'B', 'C', 'A', 'F'])
        b.add_to_train(['a', 'b', 'd', 'd', 'f'], ['A', 'B', 'D', 'D', 'F'])
        b.add_to_train(['e', 'b', 'd', 'd', 'f'], ['E', 'B', 'D', 'D', 'F'])
        b.add_to_train(['d', 'b', 'd', 'd', 'f'], ['D', 'B', 'D', 'D', 'F'])
        b.add_to_train(['c', 'b', 'd', 'd', 'f'], ['C', 'B', 'D', 'D', 'F'])
        b.add_to_train(['b', 'b', 'd', 'd', 'f'], ['B', 'B', 'D', 'D', 'F'])
        b.train()

		puts a.log_likelihood(['a', 'b', 'c', 'd', 'e'])
		puts b.log_likelihood(['a', 'b', 'c', 'd', 'f'])
        puts "\n"
    end  

	should "decode using hand-built model" do
		# apply classifier to a sample observation string
		q_star = @simple_model.decode(["A","B","A"])
		assert q_star == ["Z", "X", "X"]
	end

	should "compute forward probabilities" do
		expected_alpha = NArray[ [ 0.1, 0.2272, 0.039262 ], 
						[ 0.21, 0.0399, 0.03038 ], 
						[ 0.18, 0.0073, 0.031221 ] ]

		assert close_enough(expected_alpha, \
			@simple_model.forward_probability(["A","B","A"]).collect{|x| Math::E**x})
	end
		
	should "compute backward probabilities" do
		expected_beta = NArray[ [ 0.2271, 0.32, 1.0 ], 
						[ 0.1577, 0.66, 1.0 ], 
						[ 0.2502, 0.25, 1.0 ] ]

		assert close_enough(expected_beta, \
			@simple_model.backward_probability(["A","B","A"]).collect{|x| Math::E**x})
	end
	
	should "compute sequence likelihoods" do
		assert @simple_model.likelihood(["A", "A"]) \
			+@simple_model.likelihood(["A", "B"]) \
			+@simple_model.likelihood(["B", "B"]) \
			+@simple_model.likelihood(["B", "A"]) \
			== 1
	end
		
	should "compute xi" do
		@simple_model.gamma(@simple_model.xi(["A","B","A"]))
	end
		
	
	
	def close_enough(a, b)
		# since we're dealing with some irrational values from logs, some checks
		# need to be "good enough" rather than a perfect ==
		(a-b).abs < 1e-10
	end

end
