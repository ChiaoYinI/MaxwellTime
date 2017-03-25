using MaxwellTime
using Mesh
using Base.Test
using Utils
using MUMPS
using LinearSolvers
using KrylovMethods


L  = [4096, 4096, 2048.0]
x0 = [0.0,  0.0,  0.0]
n  = [16,  16,  16]
h  = L./n

xmin = 1548.0; xmax = 2548.0
ymin = 1548.0; ymax = 2548.0
zmin = 524.0;  zmax = 1524.0


S  = createOcTreeFromBox(x0[1],x0[2],x0[3],n[1],n[2],n[3],h[1],h[2],h[3],xmin,xmax,ymin,ymax,zmin,zmax,1,1)
M  = getOcTreeMeshFV(S,h;x0=x0)

Xe1, Xe2, Xe3 = getEdgeGrids(M)
Xc		      = getCellCenteredGrid(M)


# setup loop source
pc      = [x0[1] + n[1]*h[1]/2, x0[2] + n[2]*h[2]/2, x0[3] + n[3]*h[3]/2]

flightPath = -1000:500:1000
ns         = length(flightPath)
nr         = ns
Curl       = getCurlMatrix(M)

Sources = zeros(size(Curl,1),ns)
P       = spzeros(size(Curl,2),ns)

for i=1:ns

   # Define sources
	p       = [pc[1]-10+flightPath[i]  pc[2]-10   pc[3]
				  pc[1]-10+flightPath[i]  pc[2]+10   pc[3]
			  	  pc[1]+10+flightPath[i]  pc[2]+10   pc[3]
			  	  pc[1]+10+flightPath[i]  pc[2]-10   pc[3]
			     pc[1]-10+flightPath[i]  pc[2]-10   pc[3]] 


	a1           = magnetostaticsCurrentPoly(Xe1, p)
	a2           = magnetostaticsCurrentPoly(Xe2, p)
	a3           = magnetostaticsCurrentPoly(Xe3, p)
	a            = [a1[:,1]; a2[:,2]; a3[:,3]] 
	Sources[:,i] = 1e8*Curl*a

	# Define receivers
	P[:,i]       = getEdgeIntegralOfPolygonalChain(M,p)

end

t       = [1:6;]*1e-4 #[0; logspace(-6,-2,25)] #[0,1.3,2.7,4.5,6.4]*1e-8; #        
dt      = diff(t)
wave    = zeros(length(dt)+1); wave[1] = 1.0

sigma   = zeros(M.nc)+1e-2
sigma[Xc[:,3] .> 1024] = 1e-8


param = getMaxwellTimeSEParam(M,Sources,P,dt,wave)

tic()
D,param = getData(sigma,param);
toc()

println(" ")
println("==========  Derivative Test ======================")
println(" ")

z = rand(size(sigma))*1e-2;z[sigma.<0.009] = 0;
Jz = getSensMatVec(z,sigma,param)

for i=1:10
	alpha = 2.0^(-i)
	D1, = getData(sigma+alpha*z,param)
	
	
	println(alpha,"      ",norm(D1[:]-D[:]),"       ",norm(D1[:]-D[:]-alpha*Jz))
end


println(" ")
println("==========  Adjoint Test ======================")
println(" ")

v  = randn(prod(size(D)))
tic()
D,param = getData(sigma,param)
Jz = getSensMatVec(z,sigma,param)
toc()
I1 = dot(v,Jz)

tic()
D,param = getData(sigma,param)
JTz = getSensTMatVec(v,sigma,param)
toc()

I2 = dot(JTz,z)

println(I1,"      ",I2)
@test abs(I1-I2)/abs(I1) < 1e-5
