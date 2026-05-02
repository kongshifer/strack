# Validation Results

| Case | Description | keff | Expected | Abs Error | Tol |
| --- | --- | ---: | ---: | ---: | ---: |
| [homogeneous_cube_1g](../homogeneous_cube_1g/homogeneous_cube_1g.md) | Fully reflective 3D homogeneous 1-group cube used to track the kinf limit. | 1.249955 | 1.250000 | 0.000045 | 0.080000 |
| [homogeneous_square_2g](../homogeneous_square_2g/homogeneous_square_2g.md) | Reflective 2D-equivalent 2-group homogeneous square for scattering/fission coupling. | 1.257143 | 1.257143 | 0.000000 | 0.100000 |
| [reflective_sphere_1g](../reflective_sphere_1g/reflective_sphere_1g.md) | Reflective 1-group sphere used to exercise curved-surface tracking. | 1.099876 | 1.100000 | 0.000124 | 0.100000 |
| [slab_1d_1g](../slab_1d_1g/slab_1d_1g.md) | Literature 1D vacuum slab benchmark represented through the code's multidimensional geometry path. | 0.953009 | 0.953480 | 0.000471 | 0.001000 |
| [unstructured_circle_square_2g](../unstructured_circle_square_2g/unstructured_circle_square_2g.md) | Explicit 2D two-region circle-in-square benchmark used to track heterogeneous keff behavior. | 1.178010 | 1.174655 | 0.003355 | 0.005000 |
| [jeff15_pincell_explicit_1g](../jeff15_pincell_explicit_1g/jeff15_pincell_explicit_1g.md) | JEFF Report 15 style pin-cell explicit CSG baseline. | 0.808898 | 0.808898 | 0.000000 | 0.000001 |
| [jeff15_pincell_hierarchical_1g](../jeff15_pincell_hierarchical_1g/jeff15_pincell_hierarchical_1g.md) | Same pin-cell modeled through pin+universe hierarchy and compared with explicit CSG. | 0.808898 | 0.808898 | 0.000000 | 0.000000 |
| [jeff15_7x7_explicit_1g](../jeff15_7x7_explicit_1g/jeff15_7x7_explicit_1g.md) | JEFF Report 15 style 7x7 pin-pattern explicit CSG baseline. | 0.833326 | 0.833326 | 0.000000 | 0.000001 |
| [jeff15_7x7_hierarchical_1g](../jeff15_7x7_hierarchical_1g/jeff15_7x7_hierarchical_1g.md) | Same 7x7 pin-pattern modeled through pin+lattice+universe hierarchy and compared with explicit CSG. | 0.833326 | 0.833326 | 0.000000 | 0.000000 |
