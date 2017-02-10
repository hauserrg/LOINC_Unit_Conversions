/*  Notes

Overview:  This file contains an algorithm to select pairs of LOINC codes where the unit of measure for one LOINC code may be converted to the unit of measure of the other LOINC code.  For example, the LOINC codes 14334-7 and 3719-2 both measure lithium in serum or plasma, but they different in the unit.  The code 14334-7 uses moles per liter, while code 3719-2 uses micrograms per milliliter.  The results of these tests can be converted by multiplication factor to account for the different units.  The output of the algorithm required manual review to determine if the units of the two codes were truely compatible.  

This codes uses T-SQL, a Microsoft derivative of SQL.

Prerequisites:
	a.  LOINC version 2_28 loaded into table "Dim_Loinc_2_28".
		The schema of the table is listed here for reference:
		
		CREATE TABLE [Dim_Loinc_2_58](
			[LoincId] [varchar](10) NOT NULL, primary key(LoincId)
			[component] [varchar](255) NULL,
			[property] [varchar](30) NULL,
			[time_aspct] [varchar](15) NULL,
			[system] [varchar](100) NULL,
			[scale_typ] [varchar](30) NULL,
			[method_typ] [varchar](50) NULL,
			[class] [varchar](20) NULL,
			[VersionLastChanged] [varchar](10) NULL,
			[chng_type] [varchar](3) NULL,
			[DefinitionDescription] [text] NULL,
			[status] [varchar](11) NULL,
			[consumer_name] [varchar](255) NULL,
			[classtype] [int] NULL,
			[formula] [text] NULL,
			[species] [varchar](20) NULL,
			[exmpl_answers] [text] NULL,
			[survey_quest_text] [text] NULL,
			[survey_quest_src] [varchar](50) NULL,
			[unitsrequired] [varchar](1) NULL,
			[submitted_units] [varchar](30) NULL,
			[relatednames2] [text] NULL,
			[shortname] [varchar](40) NULL,
			[order_obs] [varchar](15) NULL,
			[cdisc_common_tests] [varchar](1) NULL,
			[hl7_field_subfield_id] [varchar](50) NULL,
			[external_copyright_notice] [text] NULL,
			[example_units] [varchar](255) NULL,
			[long_common_name] [varchar](255) NULL,
			[UnitsAndRange] [text] NULL,
			[document_section] [varchar](255) NULL,
			[example_ucum_units] [varchar](255) NULL,
			[example_si_ucum_units] [varchar](255) NULL,
			[status_reason] [varchar](9) NULL,
			[status_text] [text] NULL,
			[change_reason_public] [text] NULL,
			[common_test_rank] [int] NULL,
			[common_order_rank] [int] NULL,
			[common_si_test_rank] [int] NULL,
			[hl7_attachment_structure] [varchar](15) NULL,
			[ExternalCopyrightLink] [varchar](255) NULL,
			[PanelType] [varchar](50) NULL,
			[AskAtOrderEntry] [varchar](255) NULL,
			[AssociatedObservations] [varchar](255) NULL,
			[VersionFirstReleased] [varchar](255) NULL,
			[ValidHL7AttachmentRequest] [varchar](255) NULL,
		)
*/

IF OBJECT_ID('tempDb..#Loinc', 'U') IS NOT NULL DROP TABLE #Loinc
select *
into #Loinc
from [Dim_Loinc_2_58]
where example_ucum_units is not null and (common_test_rank != 0 or common_si_test_rank != 0) and classtype = 1

--update albumin component on a Loinc code
update l
set component = 'Albumin'
from #Loinc l
where LoincId = '58448-2'

--Find the components with at least two units
if object_id('tempDb..#componentUnit', 'U') is not null drop table #componentUnit
select distinct component
into #componentUnit
from (
	select row_number() over(partition by component order by component) RowId, component, example_ucum_units
	from (
		select component, example_ucum_units
		from #Loinc
		group by component, example_ucum_units
	) t
) t
where RowId > 1

--Mark groups with at least two units
if object_id('tempDb..#componentTwoUnits', 'U') is not null drop table #componentTwoUnits
select l.loincId, l.component, l.long_common_name, l.example_ucum_units, l.[system]
into #componentTwoUnits
from #Loinc l
join #componentUnit c on l.component = c.component
order by l.component

----This a a major output.
--select distinct c1.example_ucum_units, c2.example_ucum_units
--from #componentTwoUnits c1
--join #componentTwoUnits c2 on c1.component = c2.component
--where c1.example_ucum_units < c2.example_ucum_units

----This a a major output.
--select distinct c1.[system], c2.[system]
--from #componentTwoUnits c1
--join #componentTwoUnits c2 on c1.component = c2.component
--where c1.[system] < c2.[system]

IF OBJECT_ID('tempDb..#UniqSpec', 'U') IS NOT NULL DROP TABLE #UniqSpec
create table #UniqSpec
(
	Id int identity(1,1), primary key(Id),
	GroupId int,
	[System] varchar(100)
)
insert into #UniqSpec values
(1, 'XXX'),
(2, 'Urine'),
(3, 'Stool'),
(4, 'Ser/Plas'),
(4, 'Ser'),
(4, 'Plas'),
(4, 'Bld'),
(4, 'BldV'),
(4, 'BldA'),
(4, 'Bld.dot'),
(5, 'Semen'),
(6, 'Body fld'),
(6, 'Synv fld'),
(6, 'Plr fld'),
(7, 'CSF'),
(8, 'Retic'),
(9, 'Amnio fld'),
(10, '^Population'),
(11, '^Fetus'),
(12, 'RBC'),
(13, 'BldCoV'), --crd blood
(14, 'BldCoA'), --core blood
(15, 'Urine sed')

IF OBJECT_ID('tempDb..#ManualReview', 'U') IS NOT NULL DROP TABLE #ManualReview
select u1.LoincId LoincId1, u2.LoincId LoincId2, u1.long_common_name [Name1], u2.long_common_name [Name2], u1.example_ucum_units Unit1, u2.example_ucum_units Unit2
into #ManualReview
from #componentTwoUnits u1
left join #componentTwoUnits u2 on u2.component = u1.component
left join #UniqSpec s1 on s1.[system] = u1.[system]
left join #UniqSpec s2 on s2.[system] = u2.[system]
where u1.LoincId < u2.LoincId  and (s1.GroupId = s2.GroupId or s1.GroupId is null or s2.GroupId is null)
and u1.example_ucum_units != u2.example_ucum_units
order by u1.long_common_name, u1.example_ucum_units

insert into #ManualReview 
select u1.LoincId LoincId1, u2.LoincId LoincId2, u1.long_common_name [Name1], u2.long_common_name [Name2], u1.example_ucum_units Unit1, u2.example_ucum_units Unit2
from (select * from #Loinc where LoincId = '2095-8') u1
cross apply (select * from #Loinc where LoincId = '9830-1') u2

IF OBJECT_ID('tempDb..#UnitClass', 'U') IS NOT NULL DROP TABLE #UnitClass
create table #UnitClass
(
	Id int identity(1,1), primary key(Id),
	Unit1 varchar(100),
	Unit2 varchar(100),
	MatchType varchar(100)
)
insert into #UnitClass values
('ng/mL',	'{M.o.M}',	'Units not compatible'),
('umol/L',	'ug/dL',	'Moles to mass*'),
('ng/mL',	'ng/dL',	'SI unit'),
('k[IU]/L',	'[arb''U]',	'Unknown'),
('[arb''U]/mL',	'{Index_val}',	'Unknown'),
('mg/L',	'mg/(24.h)',	'Units not compatible'),
('mmol/L',	'mg/dL',	'Moles to mass*'),
('mg/dL',	'mg/L',	'SI unit'),
('mg/dL',	'mg/(24.h)',	'Units not compatible'),
('mg/dL',	'mmol/L',	'Moles to mass*'),
('mm[Hg]',	'mmol/L',	'Units not compatible'),
('mmol/L',	'mm[Hg]',	'Units not compatible'),
('HDL/cholesterol.total',	'cholesterol.total/HDL',	'Reciprocol'),
('m[IU]/mL',	'{M.o.M}',	'Units not compatible'),
('mmol/L',	'[IU]/mL',	'Unknown'),
('ug/dL',	'ug/(24.h)',	'Units not compatible'),
('ng/mL',	'U/L',	'Unknown'),
('g/(24.h)',	'mg/dL',	'Units not compatible'),
('mg/dL',	'g/(24.h)',	'Units not compatible'),
('{Index_val}',	'{titer}',	'Unknown'),
('{titer}',	'[IU]/mL',	'Unknown'),
('ug/L',	'ug/(24.h)',	'Units not compatible'),
('pg/mL',	'ug/(24.h)',	'Units not compatible'),
('{titer}',	'[arb''U]/mL',	'Unknown'),
('{Index_val}',	'[arb''U]/mL',	'Unknown'),
('[IU]/mL',	'{Index_val}',	'Unknown'),
('fL',	'%',	'Unknown'),
('/[HPF]',	'/uL',	'Field to volume'),
('/[HPF]',	'/mL',	'Field to volume'),
('10*3/uL',	'/uL',	'Multiplier'),
('/uL',	'/mL',	'SI unit'),
('/mL',	'/uL',	'SI unit'),
('{M.o.M}',	'ng/mL',	'Units not compatible'),
('g/L',	'g/dL',	'SI unit'),
('U/mL{RBCs}',	'U/g{Hb}',	'Unknown'),
('[IU]/mL',	'{copies}/mL',	'Unknown'),
('m[IU]/mL',	'{Index_val}',	'Unknown'),
('{copies}/mL',	'{log_copies}/mL',	'Multiplier'),
('{copies}/mL',	'{Log_IU}/mL',	'Unknown'),
('{Log_IU}/mL',	'{log_copies}/mL',	'Unknown'),
('k[IU]/mL',	'{log_copies}/mL',	'Unknown'),
('k[IU]/mL',	'{copies}/mL',	'Unknown'),
('k[IU]/mL',	'{Log_IU}/mL',	'Unknown'),
('{copies}/mL',	'[IU]/mL',	'Unknown'),
('[IU]/mL',	'{log_copies}/mL',	'Unknown'),
('/uL',	'/[HPF]',	'Field to volume'),
('mg/dL',	'nmol/L',	'Moles to mass*'),
('mol/L',	'ug/mL',	'Moles to mass*'),
('ng/mL',	'ug/(24.h)',	'Units not compatible'),
('mg/(24.h)',	'mg/dL',	'Units not compatible'),
('mg/(24.h)',	'g/dL',	'Units not compatible'),
('mg/dL',	'g/dL',	'SI unit'),
('ug/mL',	'ug/(24.h)',	'Units not compatible'),
('nmol/L',	'pg/mL',	'Moles to mass*'),
('[arb''U]',	'{titer}',	'Units not compatible'),
('ug/mL',	'mg/(24.h)',	'Units not compatible'),
('umol/(24.h)',	'mg/(24.h)',	'Moles to mass*'),
('umol/(24.h)',	'ug/mL',	'Units not compatible'),
('{titer}',	'[arb''U]',	'Unknown'),
('{titer}',	'{Index_val}',	'Unknown'),
('[arb''U]',	'{Index_val}',	'Unknown'),
('ng/mL',	'ug/L',	'SI unit'),
('ng/mL',	'[IU]/L',	'Unknown'),
('g/dL',	'mg/dL',	'SI unit'),
('g/dL',	'g/(24.h)',	'Units not compatible'),
('[arb''U]/mL',	'[IU]/mL',	'Unknown'),
('ug/mL',	'mg/dL',	'SI unit'),
('mmol/(24.h)',	'mmol/L',	'Units not compatible'),
('mol/L',	'mmol/L',	'SI unit'),
('mol/L',	'mmol/(24.h)',	'Units not compatible'),
('mmol/L',	'mmol/(24.h)',	'Units not compatible'),
('um/s',	'10*3/uL',	'Units not compatible'),
('mmol/L',	'pg/mL',	'Moles to mass*'),
('ug/dL',	'nmol/L',	'Moles to mass*'),
('nmol/L',	'ug/dL',	'Moles to mass*'),
('ng/dL',	'{Index_val}',	'Unknown'),
('{Ehrlich''U}/dL',	'mg/dL',	'Unknown'),
('mL',	'L',	'SI unit'),
('{ratio}',	'{ratio}',	'Ratio'),
('mg/(24.h)',	'ug/min',	'SI unit'),
('mg/dL',	'ug/min',	'Units not compatible'),
('ug/min',	'g/dL',	'Units not compatible'),
('{Ehrlich''U}/dL',	'umol/L',	'Unknown'),
('g/(24.h)',	'umol/L',	'Units not compatible'),
('mg/dL',	'umol/L',	'Moles to mass*'),
('mg/L',	'umol/L',	'Moles to mass*'),
('mmol/(24.h)',	'umol/L',	'Units not compatible'),
('mmol/L',	'umol/L',	'SI unit'),
('ng/mL',	'umol/L',	'Moles to mass*'),
('pg/mL',	'umol/L',	'Moles to mass*'),
('ug/(24.h)',	'umol/L',	'Units not compatible'),
('ug/dL',	'umol/L',	'Moles to mass*'),
('ug/mL',	'umol/L',	'Moles to mass*'),
('umol/(24.h)',	'umol/L',	'Units not compatible'),
('ug/dL',	'umol/dL',	'Moles to mass*'),
('mmol/L',	'ug/mL',	'Moles to mass*'),
('nmol/(24.h)',	'ug/mL',	'Units not compatible'),
('nmol/L',	'ug/mL',	'Moles to mass*'),
('umol/L',	'ug/mL',	'Moles to mass*'),
('nmol/(24.h)',	'ug/L',	'Units not compatible'),
('nmol/L',	'ug/L',	'Moles to mass*'),
('nmol/(24.h)',	'ug/(24.h)',	'Moles to mass*'),
('nmol/L',	'ug/(24.h)',	'Moles to mass*'),
('umol/(24.h)',	'ug/(24.h)',	'Moles to mass*'),
('pmol/L',	'u[IU]/mL',	'Unknown'),
('mmol/L',	'pmol/L',	'SI unit'),
('ng/dL',	'pmol/L',	'Moles to mass*'),
('nmol/L',	'pmol/L',	'SI unit'),
('pg/mL',	'pmol/L',	'Moles to mass*'),
('ug/dL',	'pmol/L',	'Moles to mass*'),
('pmol/L',	'pg/mL',	'Moles to mass*'),
('ng/dL',	'nmol/L',	'Moles to mass*'),
('ng/mL',	'nmol/L',	'Moles to mass*'),
('nmol/(24.h)',	'nmol/L',	'Units not compatible'),
('pg/mL',	'nmol/L',	'Moles to mass*'),
('ug/(24.h)',	'nmol/L',	'Units not compatible'),
('ug/mL',	'nmol/L',	'Moles to mass*'),
('umol/(24.h)',	'nmol/L',	'Units not compatible'),
('nmol/L',	'nmol/(24.h)',	'Moles to mass*'),
('pg/mL',	'nmol/(24.h)',	'Moles to mass*'),
('ug/dL',	'nmol/(24.h)',	'Moles to mass*'),
('nmol/L',	'ng/mL',	'Moles to mass*'),
('pmol/L',	'ng/mL',	'Moles to mass*'),
('umol/(24.h)',	'ng/mL',	'Units not compatible'),
('umol/L',	'ng/mL',	'Moles to mass*'),
('nmol/L',	'ng/dL',	'Moles to mass*'),
('pmol/L',	'ng/dL',	'Moles to mass*'),
('mg/dL',	'mol/L',	'Moles to mass*'),
('{ratio}',	'mmol/mol',	'Unknown'),
('mg/(24.h)',	'mmol/L',	'Units not compatible'),
('mg/L',	'mmol/L',	'Moles to mass*'),
('pmol/L',	'mmol/L',	'SI unit'),
('ug/mL',	'mmol/L',	'Moles to mass*'),
('umol/L',	'mmol/(24.h)',	'Moles to mass*'),
('mmol/(24.h)',	'mg/L',	'Units not compatible'),
('mmol/L',	'mg/L',	'Moles to mass*'),
('umol/L',	'mg/L',	'Moles to mass*'),
('mmol/(24.h)',	'mg/dL',	'Units not compatible'),
('umol/(24.h)',	'mg/dL',	'Units not compatible'),
('umol/L',	'mg/dL',	'Moles to mass*'),
('mmol/(24.h)',	'mg/(24.h)',	'Moles to mass*'),
('mmol/L',	'mg/(24.h)',	'Moles to mass*'),
('umol/L',	'mg/(24.h)',	'Moles to mass*'),
('mmol/(24.h)',	'g/(24.h)',	'Moles to mass*'),
('mmol/L',	'g/(24.h)',	'Moles to mass*'),
('umol/L',	'g/(24.h)',	'Moles to mass*'),
('nmol/L',	'{M.o.M}',	'Units not compatible'),
('{ratio}',	'%',	'Unknown')

select m.*, c.MatchType
into #Temp2
from #ManualReview m
left join #UnitClass c on m.Unit1 = c.Unit1 and m.unit2 = c.Unit2
order by Name1

----------------- Debug only:
--select * 
--from #ManualReview m
--where LoincId1 in ('2026-3','2019-8')

--select *
--from #componentTwoUnits
--where LoincId in ('2026-3','2019-8')

--select *
--from #Loinc
--where LoincId in ('2026-3','2019-8')

--select *
--from X1.Dim_Loinc
--where LoincId = '33022-5'

--select *
--from X1.Dim_Loinc
--where LoincId in ('2026-3','2019-8')

-- select * from #Temp2 --444
-- except
-- select * from #Temp1 --134
