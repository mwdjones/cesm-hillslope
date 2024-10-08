module initVerticalMod

#include "shr_assert.h"

  !-----------------------------------------------------------------------
  ! !DESCRIPTION
  ! Initialize vertical components of column datatype
  !
  use shr_kind_mod      , only : r8 => shr_kind_r8
  use shr_infnan_mod    , only : nan => shr_infnan_nan, assignment(=)
  use shr_log_mod       , only : errMsg => shr_log_errMsg
  use shr_sys_mod       , only : shr_sys_abort
  use decompMod         , only : bounds_type
  use spmdMod           , only : masterproc
  use clm_varpar        , only : nlevsno, nlevgrnd, nlevlak
  use clm_varpar        , only : toplev_equalspace, nlev_equalspace
  use clm_varpar        , only : nlevsoi, nlevsoifl, nlevurb, nlevmaxurbgrnd
  use clm_varctl        , only : fsurdat, iulog
  use clm_varctl        , only : use_vancouver, use_mexicocity, use_extralakelayers
  use clm_varctl        , only : use_bedrock, rundef
  use clm_varctl        , only : soil_layerstruct_predefined, soil_layerstruct_userdefined
  use clm_varctl        , only : use_fates
  use clm_varcon        , only : zlak, dzlak, zsoi, dzsoi, zisoi, dzsoi_decomp, spval, ispval, grlnd 
  use column_varcon     , only : icol_roof, icol_sunwall, icol_shadewall, is_hydrologically_active
  use landunit_varcon   , only : istdlak, istice
  use fileutils         , only : getfil
  use LandunitType      , only : lun                
  use GridcellType      , only : grc                
  use ColumnType        , only : col                
  use glcBehaviorMod    , only : glc_behavior_type
  use abortUtils        , only : endrun    
  use ncdio_pio
  !
  ! !PUBLIC TYPES:
  implicit none
  save
  private
  !
  ! !PUBLIC MEMBER FUNCTIONS:
  public :: initVertical
  public :: find_soil_layer_containing_depth
  public :: readParams
  public :: setSoilLayerClass
  
  ! !PRIVATE MEMBER FUNCTIONS:
  private :: hasBedrock  ! true if the given column type includes bedrock layers
  type, private :: params_type
     real(r8) :: slopebeta      ! exponent for microtopography pdf sigma (unitless)
     real(r8) :: slopemax       ! max topographic slope for microtopography pdf sigma (unitless)
  end type params_type
  type(params_type), private ::  params_inst
  !

  character(len=*), parameter, private :: sourcefile = &
       __FILE__

  !
  !------------------------------------------------------------------------

contains

  !-----------------------------------------------------------------------
  subroutine readParams( ncid )
    !
    ! !USES:
    use ncdio_pio, only: file_desc_t
    use paramUtilMod, only: readNcdioScalar
    !
    ! !ARGUMENTS:
    implicit none
    type(file_desc_t),intent(inout) :: ncid   ! pio netCDF file id
    !
    ! !LOCAL VARIABLES:
    character(len=*), parameter :: subname = 'readParams_initVertical'
    !--------------------------------------------------------------------

    ! Exponent for microtopography pdf sigma (unitless)
    call readNcdioScalar(ncid, 'slopebeta', subname, params_inst%slopebeta)
    ! Max topographic slope for microtopography pdf sigma (unitless) 
    call readNcdioScalar(ncid, 'slopemax', subname, params_inst%slopemax)

  end subroutine readParams

    !------------------------------------------------------------------------
  subroutine setSoilLayerClass(bounds)

    !
    ! !ARGUMENTS:
    type(bounds_type), intent(in) :: bounds
    !
    ! LOCAL VARAIBLES:
    integer               :: c,l,j             ! indices

    ! Possible values for levgrnd_class. The important thing is that, for a given column,
    ! layers that are fundamentally different (e.g., soil vs bedrock) have different
    ! values. This information is used in the vertical interpolation in init_interp.
    !
    ! IMPORTANT: These values should not be changed lightly. e.g., try to avoid changing
    ! the values assigned to LEVGRND_CLASS_STANDARD, LEVGRND_CLASS_DEEP_BEDROCK, etc.  The
    ! problem with changing these is that init_interp expects that layers with a value of
    ! (e.g.) 1 on the source file correspond to layers with a value of 1 on the
    ! destination file. So if you change the values of these constants, you either need to
    ! adequately inform users of this change, or build in some translation mechanism in
    ! init_interp (such as via adding more metadata to the restart file on the meaning of
    ! these different values).
    !
    ! The distinction between "shallow" and "deep" bedrock is not made explicitly
    ! elsewhere. But, since these classes have somewhat different behavior, they are
    ! distinguished explicitly here.
    integer, parameter :: LEVGRND_CLASS_STANDARD        = 1
    integer, parameter :: LEVGRND_CLASS_DEEP_BEDROCK    = 2
    integer, parameter :: LEVGRND_CLASS_SHALLOW_BEDROCK = 3

    character(len=*), parameter :: subname = 'setSoilLayerClass'

    ! ------------------------------------------------------------------------
    ! Set classes of layers
    ! ------------------------------------------------------------------------

    do c = bounds%begc, bounds%endc
       l = col%landunit(c)
       if (hasBedrock(col_itype=col%itype(c), lun_itype=lun%itype(l))) then
          ! NOTE(wjs, 2015-10-17) We are assuming that points with bedrock have both
          ! "shallow" and "deep" bedrock. Currently, this is not true for lake columns:
          ! lakes do not distinguish between "shallow" bedrock and "normal" soil.
          ! However, that was just due to an oversight that is supposed to be corrected
          ! soon; so to keep things simple we assume that any point with bedrock
          ! potentially has both shallow and deep bedrock.
          col%levgrnd_class(c, 1:col%nbedrock(c)) = LEVGRND_CLASS_STANDARD
          if (col%nbedrock(c) < nlevsoi) then
             col%levgrnd_class(c, (col%nbedrock(c) + 1) : nlevsoi) = LEVGRND_CLASS_SHALLOW_BEDROCK
          end if
          col%levgrnd_class(c, (nlevsoi + 1) : nlevmaxurbgrnd) = LEVGRND_CLASS_DEEP_BEDROCK
       else
          col%levgrnd_class(c, 1:nlevmaxurbgrnd) = LEVGRND_CLASS_STANDARD
       end if
    end do

    do j = 1, nlevmaxurbgrnd
       do c = bounds%begc, bounds%endc
          if (col%z(c,j) == spval) then
             col%levgrnd_class(c,j) = ispval
          end if
       end do
    end do

  end subroutine setSoilLayerClass

  !------------------------------------------------------------------------
  subroutine initVertical(bounds, glc_behavior, thick_wall, thick_roof)
    use clm_varcon           , only : zmin_bedrock

    !
    ! !ARGUMENTS:
    type(bounds_type)   , intent(in)    :: bounds
    type(glc_behavior_type), intent(in) :: glc_behavior
    real(r8)            , intent(in)    :: thick_wall(bounds%begl:)
    real(r8)            , intent(in)    :: thick_roof(bounds%begl:)
    !
    ! LOCAL VARAIBLES:
    integer               :: c,l,g,i,j,lev     ! indices
    type(file_desc_t)     :: ncid              ! netcdf id
    logical               :: readvar 
    integer               :: dimid             ! dimension id
    character(len=256)    :: locfn             ! local filename
    real(r8) ,pointer     :: std (:)           ! read in - topo_std 
    real(r8) ,pointer     :: tslope (:)        ! read in - topo_slope 
    real(r8)              :: slope0            ! temporary
    integer               :: ier               ! error status
    real(r8)              :: scalez = 0.025_r8 ! Soil layer thickness discretization (m)
    real(r8)              :: thick_equal = 0.2
    character(len=20)     :: calc_method       ! soil layer calculation method
    real(r8) ,pointer     :: zbedrock_in(:)   ! read in - z_bedrock
    real(r8) ,pointer     :: lakedepth_in(:)   ! read in - lakedepth 
    real(r8), allocatable :: zurb_wall(:,:)    ! wall (layer node depth)
    real(r8), allocatable :: zurb_roof(:,:)    ! roof (layer node depth)
    real(r8), allocatable :: dzurb_wall(:,:)   ! wall (layer thickness)
    real(r8), allocatable :: dzurb_roof(:,:)   ! roof (layer thickness)
    real(r8), allocatable :: ziurb_wall(:,:)   ! wall (layer interface)
    real(r8), allocatable :: ziurb_roof(:,:)   ! roof (layer interface)
    real(r8)              :: depthratio        ! ratio of lake depth to standard deep lake depth 
    integer               :: begc, endc
    integer               :: begl, endl
    integer               :: jmin_bedrock
    character(len=*), parameter :: subname = 'initVertical'
    !------------------------------------------------------------------------

    begc = bounds%begc; endc= bounds%endc
    begl = bounds%begl; endl= bounds%endl

    SHR_ASSERT_ALL_FL((ubound(thick_wall)  == (/endl/)), sourcefile, __LINE__)
    SHR_ASSERT_ALL_FL((ubound(thick_roof)  == (/endl/)), sourcefile, __LINE__)

    ! Open surface dataset to read in data below 

    call getfil (fsurdat, locfn, 0)
    call ncd_pio_openfile (ncid, locfn, 0)

    ! --------------------------------------------------------------------
    ! Define layer structure for soil, lakes, urban walls and roof 
    ! Vertical profile of snow is not initialized here - but below
    ! --------------------------------------------------------------------
    
    ! Soil layers and interfaces (assumed same for all non-lake patches)
    ! "0" refers to soil surface and "nlevsoi" refers to the bottom of model soil

    if (soil_layerstruct_predefined == '10SL_3.5m' .or. soil_layerstruct_predefined == '23SL_3.5m') then
       calc_method = 'node-based'  ! node-based followed by error check
       if (soil_layerstruct_userdefined(1) /= rundef) then
          write(iulog,*) subname//' ERROR: Both soil_layerstruct_predefined and soil_layer_userdefined have values'
          call shr_sys_abort(subname//' ERROR: Cannot decide how to set the soil layer structure')
       end if
    ! thickness-based (part 1) and error check
    else if (soil_layerstruct_predefined == '49SL_10m' .or. &
             soil_layerstruct_predefined == '20SL_8.5m' .or. &
             soil_layerstruct_predefined == '4SL_2m') then
       calc_method = 'thickness-based'
       if (soil_layerstruct_userdefined(1) /= rundef) then
          write(iulog,*) subname//' ERROR: Both soil_layerstruct_predefined and soil_layer_userdefined have values'
          call shr_sys_abort(subname//' ERROR: Cannot decide how to set the soil layer structure')
       end if
    ! thickness-based (part 2) and error check
    else if (soil_layerstruct_userdefined(1) /= rundef) then
       calc_method = 'thickness-based'
       if (soil_layerstruct_predefined /= 'UNSET') then
          write(iulog,*) subname//' ERROR: Both soil_layerstruct_predefined and soil_layer_userdefined have values'
          call shr_sys_abort(subname//' ERROR: Cannot decide how to set the soil layer structure')
       end if
    else  ! error check
       write(iulog,*) subname//' ERROR: Unrecognized pre-defined and user-defined soil layer structures: ', trim(soil_layerstruct_predefined), soil_layerstruct_userdefined
       call endrun(subname//' ERROR: Unrecognized soil layer structure')
    end if

    if (calc_method == 'node-based') then
       do j = 1, nlevgrnd
          zsoi(j) = scalez*(exp(0.5_r8*(j-0.5_r8))-1._r8)    !node depths
       enddo

       if (soil_layerstruct_predefined == '23SL_3.5m') then
       ! Soil layer structure that starts with standard exponential,
       ! then has several evenly spaced layers and finishes off exponential.
       ! This allows the upper soil to behave as standard, but then continues
       ! with higher resolution to a deeper depth, so that, e.g., permafrost
       ! dynamics are not lost due to an inability to resolve temperature,
       ! moisture, and biogeochemical dynamics at the base of the active layer
          do j = toplev_equalspace + 1, toplev_equalspace + nlev_equalspace
             zsoi(j) = zsoi(j-1) + thick_equal
          enddo
          do j = toplev_equalspace + nlev_equalspace + 1, nlevgrnd
             zsoi(j) = scalez * (exp(0.5_r8 * (j - nlev_equalspace - 0.5_r8)) - 1._r8) + nlev_equalspace * thick_equal
          enddo
       end if  ! soil_layerstruct_predefined == '23SL_3.5m'

       dzsoi(1) = 0.5_r8*(zsoi(1)+zsoi(2))             !thickness b/n two interfaces
       do j = 2,nlevgrnd-1
          dzsoi(j)= 0.5_r8*(zsoi(j+1)-zsoi(j-1))
       enddo
       dzsoi(nlevgrnd) = zsoi(nlevgrnd)-zsoi(nlevgrnd-1)

       zisoi(0) = 0._r8
       do j = 1, nlevgrnd-1
          zisoi(j) = 0.5_r8*(zsoi(j)+zsoi(j+1))         !interface depths
       enddo
       zisoi(nlevgrnd) = zsoi(nlevgrnd) + 0.5_r8*dzsoi(nlevgrnd)

    else if (calc_method == 'thickness-based') then
       if (soil_layerstruct_userdefined(1) /= rundef) then
          do j = 1, nlevgrnd
             ! read dzsoi from user-entered namelist vector
             dzsoi(j) = soil_layerstruct_userdefined(j)
          end do
       else if (soil_layerstruct_predefined == '49SL_10m') then
          ! 10 meter soil column, nlevsoi set to 49 in clm_varpar
          do j = 1, 10
             dzsoi(j) = 1.e-2_r8     ! 10-mm layers
          enddo
          do j = 11, 19
             dzsoi(j) = 1.e-1_r8     ! 100-mm layers
          enddo
          do j = 20, nlevsoi+1       ! 300-mm layers
             dzsoi(j) = 3.e-1_r8
          enddo
          do j = nlevsoi+2,nlevgrnd  ! 10-m bedrock layers
             dzsoi(j) = 10._r8
          enddo
       else if (soil_layerstruct_predefined == '20SL_8.5m') then
          do j = 1, 4  ! linear increase in layer thickness of...
             dzsoi(j) = j * 0.02_r8                     ! ...2 cm each layer
          enddo
          do j = 5, 13
             dzsoi(j) = dzsoi(4) + (j - 4) * 0.04_r8    ! ...4 cm each layer
          enddo
          do j = 14, nlevsoi
             dzsoi(j) = dzsoi(13) + (j - 13) * 0.10_r8  ! ...10 cm each layer
          enddo
          do j = nlevsoi + 1, nlevgrnd  ! bedrock layers
             dzsoi(j) = dzsoi(nlevsoi) + (((j - nlevsoi) * 25._r8)**1.5_r8) / 100._r8
          enddo
       else if (soil_layerstruct_predefined == '4SL_2m') then
          dzsoi(1) = 0.1_r8
          dzsoi(2) = 0.3_r8
          dzsoi(3) = 0.6_r8
          dzsoi(4) = 1.0_r8
          dzsoi(5) = 1.0_r8
       end if  ! thickness-based options
       
       zisoi(0) = 0._r8
       do j = 1,nlevgrnd
          zisoi(j)= sum(dzsoi(1:j))
       enddo
       
       do j = 1, nlevgrnd
          zsoi(j) = 0.5*(zisoi(j-1) + zisoi(j))
       enddo

    else  ! error check
       write(iulog,*) subname//' ERROR: Unrecognized calc_method: ', trim(calc_method)
       call endrun(subname//' ERROR: Unrecognized calc_method')
    end if  ! calc_method is node-based or thickness-based

    ! define a vertical grid spacing such that it is the normal dzsoi if
    ! nlevdecomp =nlevgrnd
    dzsoi_decomp = dzsoi            !thickness b/n two interfaces

    if (masterproc) then
       write(iulog, *) 'zsoi', zsoi(:) 
       write(iulog, *) 'zisoi: ', zisoi(:)
       write(iulog, *) 'dzsoi: ', dzsoi(:)
       write(iulog, *) 'dzsoi_decomp: ',dzsoi_decomp
    end if

    if (nlevurb > 0) then
       allocate(zurb_wall(bounds%begl:bounds%endl,nlevurb),    &
            zurb_roof(bounds%begl:bounds%endl,nlevurb),    &
            dzurb_wall(bounds%begl:bounds%endl,nlevurb),   &
            dzurb_roof(bounds%begl:bounds%endl,nlevurb),   &
            ziurb_wall(bounds%begl:bounds%endl,0:nlevurb), &
            ziurb_roof(bounds%begl:bounds%endl,0:nlevurb), &
            stat=ier)
       if (ier /= 0) then
          call shr_sys_abort(' ERROR allocation error for '//&
               'zurb_wall,zurb_roof,dzurb_wall,dzurb_roof,ziurb_wall,ziurb_roof'//&
               errMsg(sourcefile, __LINE__))
       end if
    end if

    ! Column level initialization for urban wall and roof layers and interfaces
    do l = bounds%begl,bounds%endl

       ! "0" refers to urban wall/roof surface and "nlevsoi" refers to urban wall/roof bottom
       if (lun%urbpoi(l)) then
          if (use_vancouver) then       
             zurb_wall(l,1) = 0.010_r8/2._r8
             zurb_wall(l,2) = zurb_wall(l,1) + 0.010_r8/2._r8 + 0.020_r8/2._r8
             zurb_wall(l,3) = zurb_wall(l,2) + 0.020_r8/2._r8 + 0.070_r8/2._r8
             zurb_wall(l,4) = zurb_wall(l,3) + 0.070_r8/2._r8 + 0.070_r8/2._r8
             zurb_wall(l,5) = zurb_wall(l,4) + 0.070_r8/2._r8 + 0.030_r8/2._r8

             zurb_roof(l,1) = 0.010_r8/2._r8
             zurb_roof(l,2) = zurb_roof(l,1) + 0.010_r8/2._r8 + 0.010_r8/2._r8
             zurb_roof(l,3) = zurb_roof(l,2) + 0.010_r8/2._r8 + 0.010_r8/2._r8
             zurb_roof(l,4) = zurb_roof(l,3) + 0.010_r8/2._r8 + 0.010_r8/2._r8
             zurb_roof(l,5) = zurb_roof(l,4) + 0.010_r8/2._r8 + 0.030_r8/2._r8

             dzurb_wall(l,1) = 0.010_r8
             dzurb_wall(l,2) = 0.020_r8
             dzurb_wall(l,3) = 0.070_r8
             dzurb_wall(l,4) = 0.070_r8
             dzurb_wall(l,5) = 0.030_r8
             write(iulog,*)'Total thickness of wall: ',sum(dzurb_wall(l,:))
             write(iulog,*)'Wall layer thicknesses: ',dzurb_wall(l,:)

             dzurb_roof(l,1) = 0.010_r8
             dzurb_roof(l,2) = 0.010_r8
             dzurb_roof(l,3) = 0.010_r8
             dzurb_roof(l,4) = 0.010_r8
             dzurb_roof(l,5) = 0.030_r8
             write(iulog,*)'Total thickness of roof: ',sum(dzurb_roof(l,:))
             write(iulog,*)'Roof layer thicknesses: ',dzurb_roof(l,:)

             ziurb_wall(l,0) = 0.
             ziurb_wall(l,1) = dzurb_wall(l,1)
             do j = 2,nlevurb
                ziurb_wall(l,j) = sum(dzurb_wall(l,1:j))
             end do
             write(iulog,*)'Wall layer interface depths: ',ziurb_wall(l,:)

             ziurb_roof(l,0) = 0.
             ziurb_roof(l,1) = dzurb_roof(l,1)
             do j = 2,nlevurb
                ziurb_roof(l,j) = sum(dzurb_roof(l,1:j))
             end do
             write(iulog,*)'Roof layer interface depths: ',ziurb_roof(l,:)
          else if (use_mexicocity) then
             zurb_wall(l,1) = 0.015_r8/2._r8
             zurb_wall(l,2) = zurb_wall(l,1) + 0.015_r8/2._r8 + 0.120_r8/2._r8
             zurb_wall(l,3) = zurb_wall(l,2) + 0.120_r8/2._r8 + 0.150_r8/2._r8
             zurb_wall(l,4) = zurb_wall(l,3) + 0.150_r8/2._r8 + 0.150_r8/2._r8
             zurb_wall(l,5) = zurb_wall(l,4) + 0.150_r8/2._r8 + 0.015_r8/2._r8

             zurb_roof(l,1) = 0.010_r8/2._r8
             zurb_roof(l,2) = zurb_roof(l,1) + 0.010_r8/2._r8 + 0.050_r8/2._r8
             zurb_roof(l,3) = zurb_roof(l,2) + 0.050_r8/2._r8 + 0.050_r8/2._r8
             zurb_roof(l,4) = zurb_roof(l,3) + 0.050_r8/2._r8 + 0.050_r8/2._r8
             zurb_roof(l,5) = zurb_roof(l,4) + 0.050_r8/2._r8 + 0.025_r8/2._r8

             dzurb_wall(l,1) = 0.015_r8
             dzurb_wall(l,2) = 0.120_r8
             dzurb_wall(l,3) = 0.150_r8
             dzurb_wall(l,4) = 0.150_r8
             dzurb_wall(l,5) = 0.015_r8
             write(iulog,*)'Total thickness of wall: ',sum(dzurb_wall(l,:))
             write(iulog,*)'Wall layer thicknesses: ',dzurb_wall(l,:)

             dzurb_roof(l,1) = 0.010_r8
             dzurb_roof(l,2) = 0.050_r8
             dzurb_roof(l,3) = 0.050_r8
             dzurb_roof(l,4) = 0.050_r8
             dzurb_roof(l,5) = 0.025_r8
             write(iulog,*)'Total thickness of roof: ',sum(dzurb_roof(l,:))
             write(iulog,*)'Roof layer thicknesses: ',dzurb_roof(l,:)

             ziurb_wall(l,0) = 0.
             ziurb_wall(l,1) = dzurb_wall(l,1)
             do j = 2,nlevurb
                ziurb_wall(l,j) = sum(dzurb_wall(l,1:j))
             end do
             write(iulog,*)'Wall layer interface depths: ',ziurb_wall(l,:)

             ziurb_roof(l,0) = 0.
             ziurb_roof(l,1) = dzurb_roof(l,1)
             do j = 2,nlevurb
                ziurb_roof(l,j) = sum(dzurb_roof(l,1:j))
             end do
             write(iulog,*)'Roof layer interface depths: ',ziurb_roof(l,:)
          else
             do j = 1, nlevurb
                zurb_wall(l,j) = (j-0.5)*(thick_wall(l)/float(nlevurb))  !node depths
             end do
             do j = 1, nlevurb
                zurb_roof(l,j) = (j-0.5)*(thick_roof(l)/float(nlevurb))  !node depths
             end do

             dzurb_roof(l,1) = 0.5*(zurb_roof(l,1)+zurb_roof(l,2))    !thickness b/n two interfaces
             do j = 2,nlevurb-1
                dzurb_roof(l,j)= 0.5*(zurb_roof(l,j+1)-zurb_roof(l,j-1)) 
             enddo
             dzurb_roof(l,nlevurb) = zurb_roof(l,nlevurb)-zurb_roof(l,nlevurb-1)

             dzurb_wall(l,1) = 0.5*(zurb_wall(l,1)+zurb_wall(l,2))    !thickness b/n two interfaces
             do j = 2,nlevurb-1
                dzurb_wall(l,j)= 0.5*(zurb_wall(l,j+1)-zurb_wall(l,j-1)) 
             enddo
             dzurb_wall(l,nlevurb) = zurb_wall(l,nlevurb)-zurb_wall(l,nlevurb-1)

             ziurb_wall(l,0) = 0.
             do j = 1, nlevurb-1
                ziurb_wall(l,j) = 0.5*(zurb_wall(l,j)+zurb_wall(l,j+1))          !interface depths
             enddo
             ziurb_wall(l,nlevurb) = zurb_wall(l,nlevurb) + 0.5*dzurb_wall(l,nlevurb)

             ziurb_roof(l,0) = 0.
             do j = 1, nlevurb-1
                ziurb_roof(l,j) = 0.5*(zurb_roof(l,j)+zurb_roof(l,j+1))          !interface depths
             enddo
             ziurb_roof(l,nlevurb) = zurb_roof(l,nlevurb) + 0.5*dzurb_roof(l,nlevurb)
          end if
       end if
    end do

    do c = bounds%begc,bounds%endc
       l = col%landunit(c)

       if (lun%urbpoi(l)) then
          if (col%itype(c)==icol_sunwall .or. col%itype(c)==icol_shadewall) then
             col%z(c,1:nlevurb)  = zurb_wall(l,1:nlevurb)
             col%zi(c,0:nlevurb) = ziurb_wall(l,0:nlevurb)
             col%dz(c,1:nlevurb) = dzurb_wall(l,1:nlevurb)
             if (nlevurb < nlevgrnd) then
                col%z(c,nlevurb+1:nlevgrnd)  = spval
                col%zi(c,nlevurb+1:nlevgrnd) = spval
                col%dz(c,nlevurb+1:nlevgrnd) = spval
             end if
          else if (col%itype(c)==icol_roof) then
             col%z(c,1:nlevurb)  = zurb_roof(l,1:nlevurb)
             col%zi(c,0:nlevurb) = ziurb_roof(l,0:nlevurb)
             col%dz(c,1:nlevurb) = dzurb_roof(l,1:nlevurb)
             if (nlevurb < nlevgrnd) then
                col%z(c,nlevurb+1:nlevgrnd)  = spval
                col%zi(c,nlevurb+1:nlevgrnd) = spval
                col%dz(c,nlevurb+1:nlevgrnd) = spval
             end if
          else
             col%z(c,1:nlevgrnd)  = zsoi(1:nlevgrnd)
             col%zi(c,0:nlevgrnd) = zisoi(0:nlevgrnd)
             col%dz(c,1:nlevgrnd) = dzsoi(1:nlevgrnd)
             if (nlevgrnd < nlevurb) then
                col%z(c,nlevgrnd+1:nlevurb)  = spval
                col%zi(c,nlevgrnd+1:nlevurb) = spval
                col%dz(c,nlevgrnd+1:nlevurb) = spval
             end if
          end if
       else if (lun%itype(l) /= istdlak) then
          col%z(c,1:nlevgrnd)  = zsoi(1:nlevgrnd)
          col%zi(c,0:nlevgrnd) = zisoi(0:nlevgrnd)
          col%dz(c,1:nlevgrnd) = dzsoi(1:nlevgrnd)
          if (nlevgrnd < nlevurb) then
             col%z(c,nlevgrnd+1:nlevurb)  = spval
             col%zi(c,nlevgrnd+1:nlevurb) = spval
             col%dz(c,nlevgrnd+1:nlevurb) = spval
          end if
       end if
    end do

    if (nlevurb > 0) then
       deallocate(zurb_wall, zurb_roof, dzurb_wall, dzurb_roof, ziurb_wall, ziurb_roof)
    end if

    !-----------------------------------------------
    ! Set index defining depth to bedrock
    !-----------------------------------------------

    allocate(zbedrock_in(bounds%begg:bounds%endg))
    if (use_bedrock) then
       call ncd_io(ncid=ncid, varname='zbedrock', flag='read', data=zbedrock_in, dim1name=grlnd, readvar=readvar)
       if (.not. readvar) then
          if (masterproc) then
             call endrun( 'ERROR:: zbedrock not found on surface data set, and use_bedrock is true.'//errmsg(sourcefile, __LINE__) )
          end if
       end if

    !  if use_bedrock = false, set zbedrock to lowest layer bottom interface
    else
       if (masterproc) write(iulog,*) 'not using use_bedrock!!'
       zbedrock_in(:) = zisoi(nlevsoi)
    endif

    !  determine minimum index of minimum soil depth
    jmin_bedrock = 3
    do j = 3,nlevsoi 
       if (zisoi(j-1) < zmin_bedrock .and. zisoi(j) >= zmin_bedrock) then
          jmin_bedrock = j
       endif
    enddo

    if (masterproc) write(iulog,*) 'jmin_bedrock: ', jmin_bedrock

    !  Determine gridcell bedrock index
    do g = bounds%begg,bounds%endg
       grc%nbedrock(g) = nlevsoi
       do j = jmin_bedrock,nlevsoi 
          if (zisoi(j-1) < zbedrock_in(g) .and. zisoi(j) >= zbedrock_in(g)) then
             grc%nbedrock(g) = j
          end if
       end do
    end do

    !  Set column bedrock index
    do c = begc, endc
       g = col%gridcell(c)
       col%nbedrock(c) = grc%nbedrock(g) 
    end do

    deallocate(zbedrock_in)

    !-----------------------------------------------
    ! Set lake levels and layers (no interfaces)
    !-----------------------------------------------

    allocate(lakedepth_in(bounds%begg:bounds%endg))
    call ncd_io(ncid=ncid, varname='LAKEDEPTH', flag='read', data=lakedepth_in, dim1name=grlnd, readvar=readvar)
    if (.not. readvar) then
       if (masterproc) then
          write(iulog,*) 'WARNING:: LAKEDEPTH not found on surface data set. All lake columns will have lake depth', &
               ' set equal to default value.'
       end if
       lakedepth_in(:) = spval
    end if
    do c = begc, endc
       g = col%gridcell(c)
       col%lakedepth(c) = lakedepth_in(g)
    end do
    deallocate(lakedepth_in)

    ! Lake layers
    if (.not. use_extralakelayers) then
       dzlak(1) = 0.1_r8
       dzlak(2) = 1._r8
       dzlak(3) = 2._r8
       dzlak(4) = 3._r8
       dzlak(5) = 4._r8
       dzlak(6) = 5._r8
       dzlak(7) = 7._r8
       dzlak(8) = 7._r8
       dzlak(9) = 10.45_r8
       dzlak(10)= 10.45_r8

       zlak(1) =  0.05_r8
       zlak(2) =  0.6_r8
       zlak(3) =  2.1_r8
       zlak(4) =  4.6_r8
       zlak(5) =  8.1_r8
       zlak(6) = 12.6_r8
       zlak(7) = 18.6_r8
       zlak(8) = 25.6_r8
       zlak(9) = 34.325_r8
       zlak(10)= 44.775_r8
    else
       dzlak(1) =0.1_r8
       dzlak(2) =0.25_r8
       dzlak(3) =0.25_r8
       dzlak(4) =0.25_r8
       dzlak(5) =0.25_r8
       dzlak(6) =0.5_r8
       dzlak(7) =0.5_r8
       dzlak(8) =0.5_r8
       dzlak(9) =0.5_r8
       dzlak(10) =0.75_r8
       dzlak(11) =0.75_r8
       dzlak(12) =0.75_r8
       dzlak(13) =0.75_r8
       dzlak(14) =2_r8
       dzlak(15) =2_r8
       dzlak(16) =2.5_r8
       dzlak(17) =2.5_r8
       dzlak(18) =3.5_r8
       dzlak(19) =3.5_r8
       dzlak(20) =3.5_r8
       dzlak(21) =3.5_r8
       dzlak(22) =5.225_r8
       dzlak(23) =5.225_r8
       dzlak(24) =5.225_r8
       dzlak(25) =5.225_r8

       zlak(1) = dzlak(1)/2._r8
       do i=2,nlevlak
          zlak(i) = zlak(i-1) + (dzlak(i-1)+dzlak(i))/2._r8
       end do
    end if

    do c = bounds%begc,bounds%endc
       l = col%landunit(c)

       if (lun%itype(l) == istdlak) then

          if (col%lakedepth(c) == spval) then
             col%lakedepth(c)         = zlak(nlevlak) + 0.5_r8*dzlak(nlevlak)
             col%z_lake(c,1:nlevlak)  = zlak(1:nlevlak)
             col%dz_lake(c,1:nlevlak) = dzlak(1:nlevlak)

          else if (col%lakedepth(c) > 1._r8 .and. col%lakedepth(c) < 5000._r8) then

             depthratio                 = col%lakedepth(c) / (zlak(nlevlak) + 0.5_r8*dzlak(nlevlak)) 
             col%z_lake(c,1)            = zlak(1)
             col%dz_lake(c,1)           = dzlak(1)
             col%dz_lake(c,2:nlevlak-1) = dzlak(2:nlevlak-1)*depthratio
             col%dz_lake(c,nlevlak)     = dzlak(nlevlak)*depthratio - (col%dz_lake(c,1) - dzlak(1)*depthratio)
             do lev=2,nlevlak
                col%z_lake(c,lev) = col%z_lake(c,lev-1) + (col%dz_lake(c,lev-1)+col%dz_lake(c,lev))/2._r8
             end do

          else if (col%lakedepth(c) > 0._r8 .and. col%lakedepth(c) <= 1._r8) then

             col%dz_lake(c,:) = col%lakedepth(c) / nlevlak;
             col%z_lake(c,1)  = col%dz_lake(c,1) / 2._r8;
             do lev=2,nlevlak
                col%z_lake(c,lev) = col%z_lake(c,lev-1) + (col%dz_lake(c,lev-1)+col%dz_lake(c,lev))/2._r8
             end do

          else

             write(iulog,*)'Bad lake depth: lakedepth: ', col%lakedepth(c)
             call shr_sys_abort(errmsg(sourcefile, __LINE__))

          end if

          col%z(c,1:nlevgrnd)  = zsoi(1:nlevgrnd)
          col%zi(c,0:nlevgrnd) = zisoi(0:nlevgrnd)
          col%dz(c,1:nlevgrnd) = dzsoi(1:nlevgrnd)
          if (nlevgrnd < nlevurb) then
             col%z(c,nlevgrnd+1:nlevurb)  = spval
             col%zi(c,nlevgrnd+1:nlevurb) = spval
             col%dz(c,nlevgrnd+1:nlevurb) = spval
          end if
       end if
    end do

    ! ----------------------------------------------
    ! Set classes of layers
    ! ----------------------------------------------

    call setSoilLayerClass(bounds)

    !-----------------------------------------------
    ! Read in topographic index and slope
    !-----------------------------------------------

    allocate(tslope(bounds%begg:bounds%endg))
    call ncd_io(ncid=ncid, varname='SLOPE', flag='read', data=tslope, dim1name=grlnd, readvar=readvar)
    if (.not. readvar) then
       call shr_sys_abort(' ERROR: TOPOGRAPHIC SLOPE NOT on surfdata file'//&
            errMsg(sourcefile, __LINE__)) 
    end if
    do c = begc,endc
       g = col%gridcell(c)
       ! check for near zero slopes, set minimum value
       col%topo_slope(c) = max(tslope(g), 0.2_r8)
    end do
    deallocate(tslope)

    allocate(std(bounds%begg:bounds%endg))
    call ncd_io(ncid=ncid, varname='STD_ELEV', flag='read', data=std, dim1name=grlnd, readvar=readvar)
    if (.not. readvar) then
       call shr_sys_abort(' ERROR: TOPOGRAPHIC STDdev (STD_ELEV) NOT on surfdata file'//&
            errMsg(sourcefile, __LINE__)) 
    end if
    do c = begc,endc
       g = col%gridcell(c)
       ! Topographic variables
       col%topo_std(c) = std(g)
    end do
    deallocate(std)

    !-----------------------------------------------
    ! SCA shape function defined
    !-----------------------------------------------

    do c = begc,endc
       ! microtopographic parameter, units are meters (try smooth function of slope)
       slope0 = params_inst%slopemax**(1._r8/params_inst%slopebeta)

       if (col%is_hillslope_column(c)) then
          col%micro_sigma(c) = (atan(col%hill_slope(c)) + slope0)**(params_inst%slopebeta)
          !scs
          if(c==endc) then
             col%micro_sigma(c) = 0.05
          endif
          !col%micro_sigma(c) = 0.05
          !col%micro_sigma(c) = 0.5
       else
          col%micro_sigma(c) = (col%topo_slope(c) + slope0)**(params_inst%slopebeta)
       endif

    end do

    call ncd_pio_closefile(ncid)

  end subroutine initVertical

  !-----------------------------------------------------------------------
  subroutine find_soil_layer_containing_depth(depth, layer)
    !
    ! !DESCRIPTION:
    ! Find the soil layer that contains the given depth
    !
    ! Aborts if the given depth doesn't exist in the soil profile
    !
    ! We consider the interface between two layers to belong to the layer *above* that
    ! interface. This implies that the top interface (at exactly 0 m) is not considered
    ! to be part of the soil profile.
    !
    ! !ARGUMENTS:
    real(r8), intent(in)  :: depth  ! target depth, m
    integer , intent(out) :: layer  ! layer containing target depth
    !
    ! !LOCAL VARIABLES:
    logical :: found
    integer :: i

    character(len=*), parameter :: subname = 'find_soil_layer_containing_depth'
    !-----------------------------------------------------------------------

    if (depth <= zisoi(0)) then
       write(iulog,*) subname, ': ERROR: depth above top of soil'
       write(iulog,*) 'depth = ', depth
       write(iulog,*) 'zisoi = ', zisoi
       call endrun(msg=subname//': depth above top of soil')
    end if

    found = .false.
    do i = 1, nlevgrnd
       if (depth <= zisoi(i)) then
          layer = i
          found = .true.
          exit
       end if
    end do

    if (.not. found) then
       write(iulog,*) subname, ': ERROR: depth below bottom of soil'
       write(iulog,*) 'depth = ', depth
       write(iulog,*) 'zisoi = ', zisoi
       call endrun(msg=subname//': depth below bottom of soil')
    end if

  end subroutine find_soil_layer_containing_depth

  !-----------------------------------------------------------------------
  logical function hasBedrock(col_itype, lun_itype)
    !
    ! !DESCRIPTION:
    ! Returns true if the given column type has a representation of bedrock - i.e., a set
    ! of layers at the bottom of the column that are treated fundamentally differently
    ! from the upper layers.
    !
    ! !USES:
    use landunit_varcon, only : istice, isturb_MIN, isturb_MAX
    use column_varcon  , only : icol_road_perv
    !
    ! !ARGUMENTS:
    integer, intent(in) :: col_itype  ! col%itype value
    integer, intent(in) :: lun_itype  ! lun%itype value for the landunit on which this column sits
    ! If we had an easy way to figure out which landunit a column was on based on
    ! col_itype (which would be very helpful!), then we wouldn't need lun_itype.
    !
    ! !LOCAL VARIABLES:

    character(len=*), parameter :: subname = 'hasBedrock'
    !-----------------------------------------------------------------------

    ! TODO(wjs, 2015-10-17) I don't like that the logic here implicitly duplicates logic
    ! elsewhere in the code. For example, if there were a change in the lake code so that
    ! it no longer treated the bottom layers as bedrock, then that change would need to be
    ! reflected here. One solution would be to set some has_bedrock flag in one central
    ! place, and then have the science code use that. But that could get messy in the
    ! science code. Another solution would be to decentralize the definition of
    ! hasBedrock, so that (for example) the lake code itself sets the value for lun_itype
    ! == istdlak - that way, hasBedrock(lake) would be more likely to get updated
    ! correctly if the lake logic changes.

    if (lun_itype == istice) then
       hasBedrock = .false.
    else if (lun_itype >= isturb_MIN .and. lun_itype <= isturb_MAX) then
       if (col_itype == icol_road_perv) then
          hasBedrock = .true.
       else
          hasBedrock = .false.
       end if
    else
       hasBedrock = .true.
    end if

    ! As an independent check of the above logic, assert that, at the very least, any
    ! hydrologically-active column is given hasBedrock = .true. This is to try to catch
    ! problems with new column types being added that aren't handled properly by the
    ! above logic, since (as noted in the todo note above) there is some implicit
    ! duplication of logic between this routine and other parts of the code, which is
    ! dangerous. For example, if a new "urban lawn" type is added, then it should have
    ! hasBedrock = .true. - and this omission will hopefully be caught by this assertion.
    if (is_hydrologically_active(col_itype=col_itype, lun_itype=lun_itype)) then
       SHR_ASSERT(hasBedrock, "hasBedrock should be true for all hydrologically-active columns")
    end if

  end function hasBedrock


end module initVerticalMod
