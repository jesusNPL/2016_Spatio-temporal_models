
setwd( "C:/Users/James.Thorson/Desktop/Project_git/2016_classes_private/Spatio-temporal models/Week 7 -- spatiotemporal models/Lecture/")

# Libraries and functions
library( TMB )
library( INLA )
library( RandomFields )
library( RANN )
source( "Fn_simulate_sample_data.R")

# Simulate data
SimList = Sim_Fn( logmean=1, Scale=0.2, SD_omega=1, SD_epsilon=1, n_per_year=100, n_years=10 )

# Make triangulated mesh
mesh = inla.mesh.create( SimList$loc_xy )
spde = inla.spde2.matern(mesh)

# Area for each location
loc_extrapolation = expand.grid( "x"=seq(0,1,length=1e3), "y"=seq(0,1,length=1e3) )
NN_extrapolation = nn2( data=SimList$loc_xy, query=loc_extrapolation, k=1 )
a_s = table(factor(NN_extrapolation$nn.idx,levels=1:nrow(SimList$loc_xy))) / nrow(loc_extrapolation)

# Compile
Version = "spatial_index_model_V1"
compile( paste0(Version,".cpp") )
dyn.load( dynlib(Version) )

# Make inputs
Data = list("n_s"=SimList$n_per_year, "n_t"=SimList$n_years, "a_s"=a_s, "c_i"=SimList$DF$c_i, "s_i"=SimList$DF$s_i-1, "t_i"=SimList$DF$t_i-1, "M0"=spde$param.inla$M0, "M1"=spde$param.inla$M1, "M2"=spde$param.inla$M2)
Params = list("beta0"=0, "ln_tau_O"=log(1), "ln_tau_E"=log(1), "ln_kappa"=1, "omega_s"=rep(0,mesh$n), "epsilon_st"=matrix(0,nrow=mesh$n,ncol=Data$n_t))
Random = c("omega_s", "epsilon_st")

# Build and run
Obj = MakeADFun( data=Data, parameters=Params, random=Random )
Opt = nlminb( start=Obj$par, objective=Obj$fn, gradient=Obj$gr, control=list(trace=1, eval.max=1e4, iter.max=1e4))
Opt[["final_diagnostics"]] = data.frame( "Name"=names(Obj$par), "final_gradient"=Obj$gr(Opt$par))
Report = Obj$report()
unlist( Report[c('Range','SigmaO','SigmaE')] )
SD = sdreport( Obj, bias.correct=TRUE)
