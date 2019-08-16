*Setting libref;
libname orion "&path";

*Creating Fileref for  importing file;
FILENAME REFFILE '/folders/myfolders/Train.csv';


*Importing the test dataset and placing it in Work.Train File;
PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	replace
	OUT=WORK.Train;
	GETNAMES=YES;
RUN;
* Viewing the attributes and datatypes;
PROC CONTENTS DATA=WORK.Train; 
RUN;
* Peeking into the data;
proc print data= work.train (obs=5);
run;

* Format to identify missing data;
proc format;
 value $missfmt ' '='Missing' other='Not Missing';
 value  missfmt  . ='Missing' other='Not Missing';
run;
* Identifying missing data in character and numeric variables;
proc freq data= train;
	format _CHAR_ $missfmt.; 
	tables _char_ /missing missprint nocum nopercent;
	format _NUMERIC_ missfmt.;
	tables _numeric_ /missing missprint nocum nopercent;
run;
*Outlet_size has 2410 missing values;
*Item Weight has 1463 missing values;

* Investigating each and every variables;
*Starting with Categorical variable Item Fat Content;
proc freq data = train;
	tables Item_Fat_Content / nocum nopercent;
	run;

*Cleaning up Regular and Lowfat content;
data train;
	set work.train;
	if Item_Fat_Content = "LF" then
		Item_Fat_Content = "Low Fat";
	else if Item_Fat_Content = "low fat" then
		Item_Fat_Content ="Low Fat";
	else if Item_Fat_Content = "reg" then
		Item_Fat_Content ="Regular"; 
run;
*Generating frequency distribution between Low Fat and Regular;
proc freq data = train;
	tables Item_Fat_Content / nocum;
	run;
/* Low Fat to Regular split is 65:35 */
proc freq data = train;
	tables Item_type / nocum;
	run;
*Fruits & Vegetable and Snacks contribute maximum to the distribution;
proc freq data = train;
	tables outlet_identifier / nocum;
	run;
*Nearly equal split between all outlets;
proc freq data = train;
	tables outlet_size/ nocum;
	run;
*Since Medium represents 45% of the entire dataset we will replace
missing values with Medium Size outlets;
data train;
	set train;
	if outlet_size =' ' then
		outlet_size = "Medium";
run;
proc freq data = train;
	tables outlet_size/ nocum;
	run;
proc freq data = train;
	tables outlet_location_type/ nocum;
	run;

/**** Analyzing continous variables*/
*Analyzing item weight;
proc univariate data=train;
	var Item_Weight;
	histogram / midpoints = 4 to 22 by 3;
run;
/* Performing univariate imputation using mean */
proc stdize data=train out = train
			reponly
			method=mean;
			var Item_weight;
run;
proc freq data= train;
	format _CHAR_ $missfmt.; 
	tables _char_ /missing missprint nocum nopercent;
	format _NUMERIC_ missfmt.;
	tables _numeric_ /missing missprint nocum nopercent;
run;
*Analyzing Item Visibility percentage;
proc univariate data=train;
	var Item_Visibility;
	histogram ;
run;

proc sgplot data=train;
vbox Item_Visibility;
run;
* The data is skewed towards the left. Also presence of huge number of outliers;
*Trimming Outliers using Winsoriztion technique;
%macro pctlcap(input=, output=, class=none, vars=, pctl=10 90);

%if &output = %then %let output = &input;
  
%let varL=;
%let varH=;
%let xn=1;

%do %until (%scan(&vars,&xn)= );
%let token = %scan(&vars,&xn);
%let varL = &varL &token.L;
%let varH = &varH &token.H;
%let xn=%EVAL(&xn + 1);
%end;

%let xn=%eval(&xn-1);

data xtemp;
set &input;
run;

%if &class = none %then %do;

data xtemp;
set xtemp;
xclass = 1;
run;

%let class = xclass;
%end;

proc sort data = xtemp;
by &class;
run;

proc univariate data = xtemp noprint;
by &class;
var &vars;
output out = xtemp_pctl PCTLPTS = &pctl PCTLPRE = &vars PCTLNAME = L H;
run;

data &output;
merge xtemp xtemp_pctl;
by &class;
array trimvars{&xn} &vars;
array trimvarl{&xn} &varL;
array trimvarh{&xn} &varH;

do xi = 1 to dim(trimvars);
if not missing(trimvars{xi}) then do;
if (trimvars{xi} < trimvarl{xi}) then trimvars{xi} = trimvarl{xi};
if (trimvars{xi} > trimvarh{xi}) then trimvars{xi} = trimvarh{xi};
end;
end;
drop &varL &varH xclass xi;
run;

%mend pctlcap;

%pctlcap(input=train, output=train, class=none, vars = Item_Visibility, pctl=10 90);
* Replaced the Oultiers with 90th and 10th percentile data ;

*Analyzing Item_MRP Details;
proc univariate data=train;
	var Item_MRP;
	histogram ;
run;

/* Analyzing Item Sales by Outlet type, location, size, and product type*/

proc sql;
		select distinct(Item_Identifier), Item_Type from train
		group by Item_Type;
quit;
/* The item identifier have classified the Item Type into Food, Drinks and Non conusmable*/
*Combining categories of this classification;

data train;
	set train;
	length Item_Type_Comb $20;
		if Item_Type in ('Hard Drinks' 'Soft Drinks') 
			then Item_Type_Comb = 'Drinks';
		else if Item_Type in ('Health & Hygiene' 'Household' 'Others')
			then Item_Type_Comb = 'Non Consumable';
		else Item_Type_Comb ='Food';
run;
proc freq data = train;
	tables Item_Type_Comb/ nocum;
	run;
/* Close to 80% of the frequency fall under food category */

*Visualizing the Item Fat Content Vs Item Sales;
proc sgplot data=train;
vbar Item_Fat_Content / response=Item_Outlet_Sales stat= sum;
xaxis display= all;
run;
*Visualizing the Item Type VS Item Outlet Sales;
proc sgplot data=train;
vbar Item_Type_Comb / response=Item_Outlet_Sales categoryorder=respdesc stat= sum;
xaxis display= all;
run;
*Food Items Contribute to maximum Sales;
proc sgplot data=train;
vbar Outlet_Size / response=Item_Outlet_Sales categoryorder=respdesc stat= sum;
xaxis display= all;
run;
*Medium sized stores contribute more sales;
proc sgplot data=train;
vbar Outlet_Location_type / response=Item_Outlet_Sales categoryorder=respdesc stat= sum;
xaxis display= all;
run;
*Tier 3 contributes maximum Sales;

proc sgplot data=train;
vbar Outlet_type / response=Item_Outlet_Sales categoryorder=respdesc stat= sum;
xaxis display= all;
run;
*Supermarket Type1 contributes maximum Sales;

proc GLMMOD data=train outdesign=glmmoddesign outparm=glmparm NOPRINT; 
class Item_Fat_Content Item_Type_Comb Outlet_size Outlet_Location_Type Outlet_Type;
model Item_Outlet_Sales = Item_Fat_Content Item_Type_Comb Outlet_size Outlet_Location_Type Outlet_Type;
run;

proc reg data=glmmoddesign;
	Dummyvars : model Item_Outlet_Sales = col2-col16;
	ods select ParameterEstimates;
quit;

proc glm data=glmmoddesign;
	model Item_Outlet_Sales = col2-col16;
	run;
quit;







