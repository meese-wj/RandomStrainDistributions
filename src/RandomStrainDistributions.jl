module RandomStrainDistributions
using Reexport

using Random

include("PhysicalVectors/PhysicalVectors.jl")
@reexport using .PhysicalVectors

include("CrystalDefects.jl")
@reexport using .CrystalDefects

include("PBCImageFields.jl")
@reexport using .PBCImageFields

include("ShearFunctions.jl")
@reexport using .ShearFunctions

include("RandomDislocations.jl")

include("DisorderConfigurations.jl")
@reexport using .DisorderConfigurations

# ===================================================================== #
#  RandomStrainDistributions module code is below
# ===================================================================== #

using Distributions
export RandomStrainDistribution, RandomDislocationDistribution, collect_dislocations

"""
Interface type for the random strain distributions
"""
abstract type RandomStrainDistribution end

"""
    collect_dislocations( rsd::RandomStrainDistribution )

Infterface function to generate dislocations from a `RandomStrainDistribution`.
"""
collect_dislocations( rsd::RandomStrainDistribution ) = error("No implementation for $(typeof(rsd)) has been defined.")

"""
    system_size( rsd::RandomStrainDistribution )

Interface function which returns the system size of a `RandomStrainDistribution`.
"""
system_size( rsd::RandomStrainDistribution ) = error("No implementation for $(typeof(rsd)) has been defined.")

"""
Struct containing all information required for random strains generated by edge dislocations.

# Struct Members
* `rng::AbstractRNG`: a random number generator for reproducibility. Defaults to `Random.GLOBAL_RNG`.
* `concentration::AbstractFloat`: the concentration of dislocations in a 2D square lattice
* `vector_diff::Function`: the difference function used to for `Vector2D` types depending on boundary conditions
* `rand_num_dis::Dis`: the `Dis <: Distribution` that returns a random number of dislocations per disorder configuration
* `burgers_vector_dist::RBVD`: the distribution `RBVD <: RandomDislocation` of random Burger's vectors and locations in the `axes`
"""
struct RandomDislocationDistribution{Dis <: Distribution, RBVD <: RandomDislocation, RNG <: AbstractRNG} <: RandomStrainDistribution
    rng::RNG
    concentration::AbstractFloat
    rand_num_dis::Dis
    burgers_vector_dist::RBVD
end

"""
    RandomDislocationDistribution(; concentration, Lx, Ly = Lx, burgers_vectors = tetragonal_burgers_vectors )

Convenient keyword constructor for the `RandomDislocationDistribution` struct which makes sure the distributions agree with other members.

# Additional Information
* This keyword constructor assumes that the `RandomDislocation` is a `UniformBurgersVector`.
* This does not use `StatsBase.Truncated` because it's about an order of magnitude slower than my version in `collect_dislocations`.
"""
function RandomDislocationDistribution(; concentration, Lx, Ly = Lx, burgers_vectors = tetragonal_burgers_vectors, random_defect_number = true, rng = Random.GLOBAL_RNG )
    
    bv_dist = UniformBurgersVector(; Lx = Lx, Ly = Ly, burgers_vectors = burgers_vectors )

    rand_num = Binomial( Lx * Ly, concentration )
    if !random_defect_number
        # If the number of defects is not random, then guarantee
        # the output is always concentration * Lx * Ly 
        num = round(Int, concentration * Lx * Ly)
        if num ≤ one(num)
            @warn "The requested number of (non-random) dislocations is $num ≤ 1. Changing to 2."
            num = one(num) + one(num)
        end
        
        if num ≥ Lx * Ly
            new_num = isodd(Lx * Ly - 1) ? Lx * Ly - 2 : Lx * Ly - 1 
            @warn "The requested number of (non-random) dislocations is $num ≥ Lx × Ly == $(Lx * Ly). Resetting to $(new_num) dislocations."
            num = new_num
        end

        if isodd(num)
            new_num = num == Lx * Ly - 1 ? num - one(num) : num + one(num)
            @warn "The requested number of (non-random) dislocations is $num, which is odd. Changing to $new_num."
            num = new_num
        end
        rand_num = DiscreteUniform(num, num) # guarantees that the "random" dislocation number is always num
    end

    return RandomDislocationDistribution(  rng,
                                           concentration,
                                           rand_num,
                                           bv_dist )
end

"""
    system_size( rdd::RandomDislocationDistribution )

Alias call to the `RandomDislocation` `system_size` function.
"""
system_size( rdd::RandomDislocationDistribution ) = system_size( rdd.burgers_vector_dist )

"""
    collect_dislocations( rdd::RandomDislocationDistribution )

Alias call to the `RandomDislocation` `collect_dislocations` function.

# Additional Information
* Note that this distribution will not allow for configurations with zero dislocations or for a number of dislocations larger than the `system_size`.
* The number of dislocations is constrained to be even only so as to have a net-zero topological charge.
* This keyword constructor assumes that the `rand_num_dis` is a truncated `Binomial` `Distribution` on the interval ``{2, 4, ..., Lx \\times Ly}`` when `truncated == true`.
"""
function collect_dislocations( rdd::RandomDislocationDistribution )
    num_dis = rand(rdd.rng, rdd.rand_num_dis)
    
    while isodd(num_dis) 
        num_dis = rand(rdd.rng, rdd.rand_num_dis) 
    end
    
    while num_dis == zero(typeof(num_dis)) || num_dis > system_size(rdd) || isodd(num_dis)
        num_dis = rand(rdd.rng, rdd.rand_num_dis)
    end

    # @show num_dis
    # if !rdd.num_dis_random
    #     while num_dis != rdd.rand_num_dis.a
    #         @show num_dis
    #         num_dis = rand(rdd.rand_num_dis)
    #     end
    # end

    return collect_dislocations( rdd.rng, rdd.burgers_vector_dist, num_dis )
end

end # module RandomStrainDistributions
