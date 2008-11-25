/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/


#import "DCMTKDataHandlerCategory.h"
#import "DICOMToNSString.h"
#include "dctk.h"

#import "browserController.h"
#import "DicomImage.h"
#import "MutableArrayCategory.h"

char currentDestinationMoveAET[ 60] = "";

@implementation OsiriXSCPDataHandler (DCMTKDataHandlerCategory)

- (NSPredicate*) predicateWithString: (NSString*) s forField: (NSString*) f
{
	NSString *v = [s stringByReplacingOccurrencesOfString:@"*" withString:@""];
	NSPredicate *predicate = nil;
	
	if( [s characterAtIndex: 0] == '*' && [s characterAtIndex: [s length]-1] == '*')
		predicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", f, v];
	else if( [s characterAtIndex: 0] == '*')
		predicate = [NSPredicate predicateWithFormat:@"%K ENDSWITH[cd] %@", f, v];
	else if( [s characterAtIndex: [s length]-1] == '*')
		predicate = [NSPredicate predicateWithFormat:@"%K BEGINSWITH[cd] %@", f, v];
	else
		predicate = [NSPredicate predicateWithFormat:@"(%K BEGINSWITH[cd] %@) AND (%K ENDSWITH[cd] %@)", f, v, f, v];

	return predicate;
}

- (NSPredicate *)predicateForDataset:( DcmDataset *)dataset
{
	NSPredicate *compoundPredicate = nil;
	const char *sType = NULL;
	const char *scs = NULL;
	
	NS_DURING 
	dataset->findAndGetString (DCM_QueryRetrieveLevel, sType, OFFalse);
	
	//NSLog(@"get Specific Character set");
	if (dataset->findAndGetString (DCM_SpecificCharacterSet, scs, OFFalse).good() && scs != NULL)
	{
		[specificCharacterSet release];
		specificCharacterSet = [[NSString stringWithCString:scs] retain];
		encoding = [NSString encodingForDICOMCharacterSet:specificCharacterSet];
	}
	else {
		[specificCharacterSet release];
		specificCharacterSet = [[NSString stringWithString:@"ISO_IR 100"] retain];
		encoding = NSISOLatin1StringEncoding;
	}
	
	if (strcmp(sType, "STUDY") == 0) 
		compoundPredicate = [NSPredicate predicateWithFormat:@"hasDICOM == %d", YES];
	else if (strcmp(sType, "SERIES") == 0)
		compoundPredicate = [NSPredicate predicateWithFormat:@"study.hasDICOM == %d", YES];
	else if (strcmp(sType, "IMAGE") == 0)
		compoundPredicate = [NSPredicate predicateWithFormat:@"series.study.hasDICOM == %d", YES];
	
	NSString *dcmstartTime = nil;
	NSString *dcmendTime = nil;
	NSString *dcmstartDate = nil;
	NSString *dcmendDate = nil;
	
	int elemCount = (int)(dataset->card());
    for (int elemIndex=0; elemIndex<elemCount; elemIndex++)
	{
		NSPredicate *predicate = nil;
		DcmElement* dcelem = dataset->getElement(elemIndex);
		DcmTagKey key = dcelem->getTag().getXTag();
		
		if (strcmp(sType, "STUDY") == 0)
		{
			if (key == DCM_PatientsName)
			{
				char *pn;
				if (dcelem->getString(pn).good() && pn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:pn  DICOMEncoding:specificCharacterSet] forField: @"name"];
			}
			else if (key == DCM_PatientID)
			{
				char *pid;
				if (dcelem->getString(pid).good() && pid != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:pid  DICOMEncoding:nil] forField: @"patientID"];
			}
			else if (key == DCM_AccessionNumber)
			{
				char *pid;
				if (dcelem->getString(pid).good() && pid != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:pid  DICOMEncoding:nil] forField: @"accessionNumber"];
			}
			else if (key == DCM_StudyInstanceUID)
			{
				char *suid;
				if (dcelem->getString(suid).good() && suid != NULL)
					predicate = [NSPredicate predicateWithFormat:@"studyInstanceUID == %@", [NSString stringWithCString:suid  DICOMEncoding:nil]];
			}
			else if (key == DCM_StudyID)
			{
				char *sid;
				if (dcelem->getString(sid).good() && sid != NULL)
					predicate = [NSPredicate predicateWithFormat:@"id == %@", [NSString stringWithCString:sid  DICOMEncoding:nil]];
			}
			else if (key ==  DCM_StudyDescription)
			{
				char *sd;
				if (dcelem->getString(sd).good() && sd != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:sd  DICOMEncoding:specificCharacterSet] forField: @"studyName"];
			}
			else if (key == DCM_InstitutionName)
			{
				char *inn;
				if (dcelem->getString(inn).good() && inn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:inn  DICOMEncoding:specificCharacterSet] forField: @"institutionName"];
			}
			else if (key == DCM_ReferringPhysiciansName)
			{
				char *rpn;
				if (dcelem->getString(rpn).good() && rpn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:rpn  DICOMEncoding:specificCharacterSet] forField: @"referringPhysician"];
			}
			else if (key ==  DCM_PerformingPhysiciansName)
			{
				char *ppn;
				if (dcelem->getString(ppn).good() && ppn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:ppn  DICOMEncoding:specificCharacterSet] forField: @"performingPhysician"];
			}
			else if (key ==  DCM_ModalitiesInStudy)
			{
				char *mis;
				if (dcelem->getString(mis).good() && mis != NULL)
				{
					NSArray *predicateArray = [NSArray array];
					for( NSString *s in [[NSString stringWithCString:mis DICOMEncoding:nil] componentsSeparatedByString:@"\\"])
						predicateArray = [predicateArray arrayByAddingObject: [NSPredicate predicateWithFormat:@"ANY series.modality == %@", s]];
					
					predicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
				}
			}
			else if (key ==  DCM_Modality)
			{
				char *mis;
				if (dcelem->getString(mis).good() && mis != NULL)
				{
					NSArray *predicateArray = [NSArray array];
					for( NSString *s in [[NSString stringWithCString:mis DICOMEncoding:nil] componentsSeparatedByString:@"\\"])
						predicateArray = [predicateArray arrayByAddingObject: [NSPredicate predicateWithFormat:@"ANY series.modality == %@", s]];
					
					predicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
				}
			}
			else if (key == DCM_PatientsBirthDate)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL) {
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomDate:dateString];
				}
				if (!value) {
					predicate = nil;
				}
				else
				{
					predicate = [NSPredicate predicateWithFormat:@"(dateOfBirth >= CAST(%lf, \"NSDate\")) AND (dateOfBirth < CAST(%lf, \"NSDate\"))", [self startOfDay:value], [self endOfDay:value]];
				}
			}
			
			else if (key == DCM_StudyDate)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomDate:dateString];
				}
				
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmendDate = queryString;

				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmstartDate = queryString;
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartDate = [values objectAtIndex:0];
						dcmendDate = [values objectAtIndex:1];
					}
					else
						predicate = nil;
				}
				else{
					predicate = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\") AND date < CAST(%lf, \"NSDate\")",[self startOfDay:value],[self endOfDay:value]];
				}
			}
			else if (key == DCM_StudyTime)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomTime:dateString];
				}
  
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmendTime = queryString;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmstartTime = queryString;
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartTime = [values objectAtIndex:0];
						dcmendTime = [values objectAtIndex:1];
					}
					else
						predicate = nil;
				}
				else
				{
					predicate = [NSPredicate predicateWithFormat:@"dicomTime == %@", [value dateAsNumber]];
				}
			}
			else
				predicate = nil;
		}
		else if (strcmp(sType, "SERIES") == 0)
		{
			if (key == DCM_StudyInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"study.studyInstanceUID == %@", [NSString stringWithCString:string  DICOMEncoding:nil]];
			}
			else if (key == DCM_SeriesInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
				{
					NSString *u = [NSString stringWithCString:string  DICOMEncoding:nil];
					NSArray *uids = [u componentsSeparatedByString:@"\\"];
					NSArray *predicateArray = [NSArray array];
					
					int x;
					for(x = 0; x < [uids count]; x++)
					{
						NSString *curString = [uids objectAtIndex: x];
						
						predicateArray = [predicateArray arrayByAddingObject: [NSPredicate predicateWithFormat:@"seriesDICOMUID == %@", curString]];
						
//						NSString *format = @"*%@*" ;
//						if ([curString hasPrefix:@"*"] && [curString hasSuffix:@"*"])
//							format = @"";
//						else if ([curString hasPrefix:@"*"])
//							format = @"%@*";
//						else if ([curString hasSuffix:@"*"])
//							format = @"*%@";
//						
//						NSString *suid = [NSString stringWithFormat:format, curString];
//						
//						predicateArray = [predicateArray arrayByAddingObject: [NSPredicate predicateWithFormat:@"seriesDICOMUID like %@", suid]];
					}
					
					predicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
				}
			} 
			else if (key == DCM_SeriesDescription)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [self predicateWithString:[NSString stringWithCString:string  DICOMEncoding:specificCharacterSet] forField:@"name"];
			}
			else if (key == DCM_SeriesNumber)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"id == %@", [NSString stringWithCString:string  DICOMEncoding:specificCharacterSet]];
			}
			else if (key ==  DCM_Modality)
			{
				char *mis;
				if (dcelem->getString(mis).good() && mis != NULL)
					predicate = [NSPredicate predicateWithFormat:@"study.modality == %@", [NSString stringWithCString:mis  DICOMEncoding:nil]];
			}
			
			else if (key == DCM_SeriesDate)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomDate:dateString];
				}
  
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmendDate = queryString;
					
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];
//					predicate = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", [self endOfDay:query]];

				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];		
					
					dcmstartDate = queryString;
					
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];			
//					predicate = [NSPredicate predicateWithFormat:@"date  >= CAST(%lf, \"NSDate\")",[self startOfDay:query]];
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartDate = [values objectAtIndex:0];
						dcmendDate = [values objectAtIndex:1];
						
//						DCMCalendarDate *startDate = [DCMCalendarDate dicomDate:[values objectAtIndex:0]];
//						DCMCalendarDate *endDate = [DCMCalendarDate dicomDate:[values objectAtIndex:1]];
//
//						//need two predicates for range
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\")", [self startOfDay:startDate]];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")",[self endOfDay:endDate]];
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
					}
					else
						predicate = nil;
				}
				else
				{
					predicate = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\") AND date < CAST(%lf, \"NSDate\")",[self startOfDay:value],[self endOfDay:value]];
				}
			}
			else if (key == DCM_SeriesTime)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomTime:dateString];
				}
  
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];	
					dcmendTime = queryString;
					
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime <= %@",query];
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					dcmstartTime = queryString;
					
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime >= %@",query];
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartTime = [values objectAtIndex:0];
						dcmendTime = [values objectAtIndex:1];
						
//						NSNumber *startDate = [NSNumber numberWithInt:[[values objectAtIndex:0] intValue]];
//						NSNumber *endDate = [NSNumber numberWithInt:[[values objectAtIndex:1] intValue]];
//
//						//need two predicates for range
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"dicomTime >= %@",startDate];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"dicomTime <= %@",endDate];
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
					}
					else
						predicate = nil;
				}

				else
				{
					predicate = [NSPredicate predicateWithFormat:@"dicomTime == %@", [value dateAsNumber]];
				}
			}
			else
			{
				predicate = nil;
			}
		}
		else if (strcmp(sType, "IMAGE") == 0)
		{
			if (key == DCM_StudyInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"series.study.studyInstanceUID == %@", [NSString stringWithCString:string  DICOMEncoding:nil]];
			}
			else if (key == DCM_SeriesInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
				{
					predicate = [NSPredicate predicateWithFormat:@"series.seriesDICOMUID == %@", [NSString stringWithCString:string  DICOMEncoding:nil]];

//					NSString *u = [NSString stringWithCString:string  DICOMEncoding:nil];
//					NSString *format = @"*%@*" ;
//					if ([u hasPrefix:@"*"] && [u hasSuffix:@"*"])
//						format = @"";
//					else if ([u hasPrefix:@"*"])
//						format = @"%@*";
//					else if ([u hasSuffix:@"*"])
//						format = @"*%@";
//					NSString *suid = [NSString stringWithFormat:format, u];
//					predicate = [NSPredicate predicateWithFormat:@"series.seriesDICOMUID like %@", suid];
				}
			} 
			else if (key == DCM_SOPInstanceUID)
			{
				char *string = nil;
				
				if (dcelem->getString(string).good() && string != NULL)
				{
					NSArray *uids = [[NSString stringWithCString:string  DICOMEncoding:nil] componentsSeparatedByString:@"\\"];
					NSArray *predicateArray = [NSArray array];
					
					int x;
					for(x = 0; x < [uids count]; x++)
					{
						NSPredicate	*p = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"compressedSopInstanceUID"] rightExpression: [NSExpression expressionForConstantValue: [DicomImage sopInstanceUIDEncodeString: [uids objectAtIndex: x]]] customSelector: @selector( isEqualToSopInstanceUID:)];
						predicateArray = [predicateArray arrayByAddingObject: p];
					}
					
					predicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
				}
			}
			else if (key == DCM_InstanceNumber)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"instanceNumber == %d", [[NSString stringWithCString:string  DICOMEncoding:nil] intValue]];
			}
			else if (key == DCM_NumberOfFrames)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"numberOfFrames == %d", [[NSString stringWithCString:string  DICOMEncoding:nil] intValue]];
			}
		}
		else
		{
			NSLog( @"OsiriX supports ONLY STUDY, SERIES, IMAGE levels ! Current level: %s", sType);
		}
		
		if (predicate)
			compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate, compoundPredicate, nil]];
	}
	
	{
		NSPredicate *predicate = nil;
		
		NSTimeInterval startDate = nil;
		NSTimeInterval endDate = nil;
		
		if( dcmstartDate)
		{
			if( dcmstartTime)
			{
				DCMCalendarDate *time = [DCMCalendarDate dicomTime: dcmstartTime];
				startDate = [[[DCMCalendarDate dicomDate: dcmstartDate] dateByAddingYears: 0 months: 0 days: 0 hours: [time hourOfDay] minutes: [time minuteOfHour] seconds: [time secondOfMinute]] timeIntervalSinceReferenceDate];
			}
			else startDate = [self startOfDay: [DCMCalendarDate dicomDate: dcmstartDate]];
		}
		
		if( dcmendDate)
		{
			if( dcmendTime)
			{
				DCMCalendarDate *time = [DCMCalendarDate dicomTime: dcmendTime];
				endDate = [[[DCMCalendarDate dicomDate: dcmendDate] dateByAddingYears: 0 months: 0 days: 0 hours: [time hourOfDay] minutes: [time minuteOfHour] seconds: [time secondOfMinute]] timeIntervalSinceReferenceDate];
			}
			else endDate = [self endOfDay: [DCMCalendarDate dicomDate: dcmendDate]];
		}
		
		if( startDate && endDate)
		{
			//need two predicates for range
			
			NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\")", startDate];
			NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", endDate];
			predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
		}
		else if( startDate)
		{		
			predicate = [NSPredicate predicateWithFormat:@"date  >= CAST(%lf, \"NSDate\")", startDate];
		}
		else if( endDate)
		{
			predicate = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", endDate];
		}
		
		if (predicate)
			compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate, compoundPredicate, nil]];
	}
	
	NS_HANDLER
		NSLog(@"Exception getting predicate: %@ for dataset\n", [localException description]);
		dataset->print(COUT);
	NS_ENDHANDLER
	return compoundPredicate;
}

- (void)studyDatasetForFetchedObject:(id)fetchedObject dataset:(DcmDataset *)dataset
{
	//DcmDataset dataset;
	//lets test responses as hardwired UTF8Strings
	//use utf8Encoding rather than encoding
	
	@try
	{
		if ([fetchedObject valueForKey:@"name"])
			dataset ->putAndInsertString(DCM_PatientsName, [[fetchedObject valueForKey:@"name"] cStringUsingEncoding:encoding]);
		else
			dataset ->putAndInsertString(DCM_PatientsName, NULL);
			
		if ([fetchedObject valueForKey:@"patientID"])	
			dataset ->putAndInsertString(DCM_PatientID, [[fetchedObject valueForKey:@"patientID"] cStringUsingEncoding:encoding]);
		else
			dataset ->putAndInsertString(DCM_PatientID, NULL);
			
		if ([fetchedObject valueForKey:@"accessionNumber"])	
			dataset ->putAndInsertString(DCM_AccessionNumber, [[fetchedObject valueForKey:@"accessionNumber"] cStringUsingEncoding:encoding]);
		else
			dataset ->putAndInsertString(DCM_AccessionNumber, NULL);
			
		if ([fetchedObject valueForKey:@"studyName"])	
			dataset ->putAndInsertString( DCM_StudyDescription, [[fetchedObject valueForKey:@"studyName"] cStringUsingEncoding:encoding]);
		else
			dataset ->putAndInsertString( DCM_StudyDescription, NULL);
			
		if ([fetchedObject valueForKey:@"dateOfBirth"])
		{
			DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKey:@"dateOfBirth"]];
			dataset ->putAndInsertString(DCM_PatientsBirthDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
		}
		else
		{
			dataset ->putAndInsertString(DCM_PatientsBirthDate, NULL);
		}
		
		if ([fetchedObject valueForKey:@"date"]){
			DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKey:@"date"]];
			DCMCalendarDate *dicomTime = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKey:@"date"]];
			dataset ->putAndInsertString(DCM_StudyDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
			dataset ->putAndInsertString(DCM_StudyTime, [[dicomTime timeString] cStringUsingEncoding:NSISOLatin1StringEncoding]);	
		}
		else {
			dataset ->putAndInsertString(DCM_StudyDate, NULL);
			dataset ->putAndInsertString(DCM_StudyTime, NULL);
		}
		
		if ([fetchedObject valueForKey:@"studyInstanceUID"])
			dataset ->putAndInsertString(DCM_StudyInstanceUID,  [[fetchedObject valueForKey:@"studyInstanceUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
		else
			dataset ->putAndInsertString(DCM_StudyInstanceUID, NULL);
		
		
		if ([fetchedObject valueForKey:@"id"])
			dataset ->putAndInsertString(DCM_StudyID , [[fetchedObject valueForKey:@"id"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
		else
			dataset ->putAndInsertString(DCM_StudyID, NULL);
			
		if ([fetchedObject valueForKey:@"modality"])
		{
			NSMutableArray *modalities = [NSMutableArray array];
			
			BOOL SC = NO, SR = NO;
			
			for( NSString *m in [[fetchedObject valueForKeyPath:@"series.modality"] allObjects])
			{
				if( [modalities containsString: m] == NO)
				{
					if( [m isEqualToString:@"SR"]) SR = YES;
					else if( [m isEqualToString:@"SC"]) SC = YES;
					else [modalities addObject: m];
				}
			}
			
			if( SC) [modalities addObject: @"SC"];
			if( SR) [modalities addObject: @"SR"];
			
			dataset ->putAndInsertString(DCM_ModalitiesInStudy , [[modalities componentsJoinedByString:@"\\"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
		}
		else
			dataset ->putAndInsertString(DCM_ModalitiesInStudy , NULL);
		
			
		if ([fetchedObject valueForKey:@"referringPhysician"])
			dataset ->putAndInsertString(DCM_ReferringPhysiciansName, [[fetchedObject valueForKey:@"referringPhysician"] cStringUsingEncoding:NSUTF8StringEncoding]);
		else
			dataset ->putAndInsertString(DCM_ReferringPhysiciansName, NULL);
			
		if ([fetchedObject valueForKey:@"performingPhysician"])
			dataset ->putAndInsertString(DCM_PerformingPhysiciansName,  [[fetchedObject valueForKey:@"performingPhysician"] cStringUsingEncoding:NSUTF8StringEncoding]);
		else
			dataset ->putAndInsertString(DCM_PerformingPhysiciansName, NULL);
			
		if ([fetchedObject valueForKey:@"institutionName"])
			dataset ->putAndInsertString(DCM_InstitutionName,  [[fetchedObject valueForKey:@"institutionName"]  cStringUsingEncoding:NSUTF8StringEncoding]);
		else
			dataset ->putAndInsertString(DCM_InstitutionName, NULL);
			
		//dataset ->putAndInsertString(DCM_SpecificCharacterSet,  "ISO_IR 192") ;
		dataset ->putAndInsertString(DCM_SpecificCharacterSet,  [specificCharacterSet cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
			
		if ([fetchedObject valueForKey:@"noFiles"]) {		
			int numberInstances = [[fetchedObject valueForKey:@"noFiles"] intValue];
			char value[10];
			sprintf(value, "%d", numberInstances);
			//NSLog(@"number files: %d", numberInstances);
			dataset ->putAndInsertString(DCM_NumberOfStudyRelatedInstances, value);
		}
			
		if ([fetchedObject valueForKey:@"series"]) {
			int numberInstances = [[fetchedObject valueForKey:@"series"] count];
			char value[10];
			sprintf(value, "%d", numberInstances);
			//NSLog(@"number series: %d", numberInstances);
			dataset ->putAndInsertString(DCM_NumberOfStudyRelatedSeries, value);
		}
		
		dataset ->putAndInsertString(DCM_QueryRetrieveLevel, "STUDY");
	}
	
	@catch (NSException *e)
	{
		NSLog( @"studyDatasetForFetchedObject exception: %@", e);
	}
}

- (void)seriesDatasetForFetchedObject:(id)fetchedObject dataset:(DcmDataset *)dataset
{
	@try
	{
		if ([fetchedObject valueForKey:@"name"])	
			dataset ->putAndInsertString(DCM_SeriesDescription, [[fetchedObject valueForKey:@"name"]   cStringUsingEncoding:NSUTF8StringEncoding]);
		else
			dataset ->putAndInsertString(DCM_SeriesDescription, NULL);
			
		if ([fetchedObject valueForKey:@"date"]){

			DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKey:@"date"]];
			DCMCalendarDate *dicomTime = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKey:@"date"]];
			dataset ->putAndInsertString(DCM_SeriesDate, [[dicomDate dateString]  cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
			dataset ->putAndInsertString(DCM_SeriesTime, [[dicomTime timeString]  cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
		}
		else {
			dataset ->putAndInsertString(DCM_SeriesDate, NULL);
			dataset ->putAndInsertString(DCM_SeriesTime, NULL);
		}

		
		if ([fetchedObject valueForKey:@"modality"])
			dataset ->putAndInsertString(DCM_Modality, [[fetchedObject valueForKey:@"modality"]  cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
		else
			dataset ->putAndInsertString(DCM_Modality, NULL);
			
		if ([fetchedObject valueForKey:@"id"]) {
			NSNumber *number = [fetchedObject valueForKey:@"id"];
			dataset ->putAndInsertString(DCM_SeriesNumber, [[number stringValue]  cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
		}
		else
			dataset ->putAndInsertString(DCM_SeriesNumber, NULL);
				
		if ([fetchedObject valueForKey:@"dicomSeriesInstanceUID"])
			dataset ->putAndInsertString(DCM_SeriesInstanceUID, [[fetchedObject valueForKey:@"dicomSeriesInstanceUID"]  cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
			

		else
			dataset ->putAndInsertString(DCM_StudyInstanceUID, NULL);
		

		if ([fetchedObject valueForKey:@"noFiles"]) {
			int numberInstances = [[fetchedObject valueForKey:@"noFiles"] intValue];
			char value[10];
			sprintf(value, "%d", numberInstances);
			//NSLog(@"number series: %d", numberInstances);
			dataset ->putAndInsertString(DCM_NumberOfSeriesRelatedInstances, value);

		}
		
		dataset ->putAndInsertString(DCM_QueryRetrieveLevel, "SERIES");
	}
	
	@catch( NSException *e)
	{
		NSLog( @"********* seriesDatasetForFetchedObject exception: %@");
	}
}

- (void)imageDatasetForFetchedObject:(id)fetchedObject dataset:(DcmDataset *)dataset
{

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NS_DURING
	if ([fetchedObject valueForKey:@"sopInstanceUID"])
		dataset ->putAndInsertString(DCM_SOPInstanceUID, [[fetchedObject valueForKey:@"sopInstanceUID"]  cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
	if ([fetchedObject valueForKey:@"instanceNumber"]) {
		NSString *number = [[fetchedObject valueForKey:@"instanceNumber"] stringValue];
		dataset ->putAndInsertString(DCM_InstanceNumber, [number cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
	}
	if ([fetchedObject valueForKey:@"numberOfFrames"]) {
		NSString *number = [[fetchedObject valueForKey:@"numberOfFrames"] stringValue];
		dataset ->putAndInsertString(DCM_NumberOfFrames, [number cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
	}
	//UTF 8 Encoding
	//dataset ->putAndInsertString(DCM_SpecificCharacterSet,  "ISO_IR 192") ;
	dataset ->putAndInsertString(DCM_QueryRetrieveLevel, "IMAGE");
	NS_HANDLER
	NS_ENDHANDLER
	[pool release];
}

- (OFCondition)prepareFindForDataSet:( DcmDataset *)dataset
{
	NSManagedObjectModel *model = [[BrowserController currentBrowser] managedObjectModel];
	NSError *error = nil;
	NSEntityDescription *entity;
	NSPredicate *predicate = [self predicateForDataset:dataset];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	const char *sType;
	dataset->findAndGetString (DCM_QueryRetrieveLevel, sType, OFFalse);
	OFCondition cond;
	
//	sType = "IMAGE";
//	predicate = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"compressedSopInstanceUID"] rightExpression: [NSExpression expressionForConstantValue: [DicomImage sopInstanceUIDEncodeString: @"1.2.826.0.1.3680043.2.1143.8797283371159.20060125163148762.58"]] customSelector: @selector( isEqualToSopInstanceUID:)];
	
	if (strcmp(sType, "STUDY") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Study"];
	else if (strcmp(sType, "SERIES") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Series"];
	else if (strcmp(sType, "IMAGE") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Image"];
	else 
		entity = nil;
	
	if (entity)
	{
		[request setEntity:entity];
		
		if( strcmp(sType, "IMAGE") == 0)
			[request setPredicate: [NSPredicate predicateWithFormat:@"compressedSopInstanceUID != NIL"]];
		else
			[request setPredicate: predicate];
					
		error = nil;
		
		NSManagedObjectContext *context = [[BrowserController currentBrowser] managedObjectContext];
		
		[context retain];
		[context lock];
		
		[findArray release];
		findArray = nil;
		
		@try
		{
			findArray = [context executeFetchRequest:request error:&error];
			
			if( strcmp(sType, "IMAGE") == 0)
			{
				findArray = [findArray filteredArrayUsingPredicate: predicate];
			}
		}
		@catch (NSException * e)
		{
			NSLog( @"prepareFindForDataSet exception");
			NSLog( [e description]);
		}
		
		[context unlock];
		[context release];
		
		if (error)
		{
			findArray = nil;
			cond = EC_IllegalParameter;
		}
		else
		{
			[findArray retain];
			cond = EC_Normal;
		}
	}
	else
	{
		findArray = nil;
		cond = EC_IllegalParameter;
	}
	
	[findEnumerator release];
	findEnumerator = [[findArray objectEnumerator] retain];
	
	return cond;
	 
}

- (void) updateLog:(NSArray*) mArray
{
	if( [[BrowserController currentBrowser] isNetworkLogsActive] == NO) return;
	if( [mArray count] == 0) return;
	
	char fromTo[ 200] = "";
	
	if( logFiles) free( logFiles);
	
	logFiles = (logStruct*) malloc( sizeof( logStruct));
	
	if (strcmp( currentDestinationMoveAET, [[self callingAET] UTF8String]) == 0)
	{
		strcpy( fromTo, [[self callingAET] UTF8String]);
	}
	else
	{
		strcpy( fromTo, [[self callingAET] UTF8String]);
		strcat( fromTo, " / ");
		strcat( fromTo, currentDestinationMoveAET);
	}
	
	
	for( NSManagedObject *object in mArray)
	{
		if( [[object valueForKey:@"type"] isEqualToString: @"Series"])
		{
			FILE * pFile;
			char dir[ 1024], newdir[1024];
			unsigned int random = (unsigned int)time(NULL);
			sprintf( dir, "%s/%s%d", [[BrowserController currentBrowser] cfixedDocumentsDirectory], "TEMP/move_log_", random);
			pFile = fopen (dir,"w+");
			if( pFile)
			{
				strcpy( logFiles->logPatientName, [[object valueForKeyPath:@"study.name"] UTF8String]);
				strcpy( logFiles->logStudyDescription, [[object valueForKeyPath:@"study.studyName"] UTF8String]);
				strcpy( logFiles->logCallingAET, fromTo);
				logFiles->logStartTime = time (NULL);
				strcpy( logFiles->logMessage, "In Progress");
				logFiles->logNumberReceived = 0;
				logFiles->logNumberTotal = [[object valueForKey:@"noFiles"] intValue];
				logFiles->logEndTime = time (NULL);
				strcpy( logFiles->logType, "Move");
				strcpy( logFiles->logEncoding, "UTF-8");
				
				unsigned int random = (unsigned int)time(NULL);
				sprintf( logFiles->logUID, "%d%s", random, logFiles->logPatientName);

				fprintf (pFile, "%s\r%s\r%s\r%ld\r%s\r%s\r%d\r%ld\r%s\r%s\r\%d\r", logFiles->logPatientName, logFiles->logStudyDescription, logFiles->logCallingAET, logFiles->logStartTime, logFiles->logMessage, logFiles->logUID, logFiles->logNumberReceived, logFiles->logEndTime, logFiles->logType, logFiles->logEncoding, logFiles->logNumberTotal);
				
				fclose (pFile);
				strcpy( newdir, dir);
				strcat( newdir, ".log");
				rename( dir, newdir);
			}
		}
		else if( [[object valueForKey:@"type"] isEqualToString: @"Study"])
		{
			FILE * pFile;
			char dir[ 1024], newdir[1024];
			unsigned int random = (unsigned int)time(NULL);
			sprintf( dir, "%s/%s%d", [[BrowserController currentBrowser] cfixedDocumentsDirectory], "TEMP/move_log_", random);
			pFile = fopen (dir,"w+");
			if( pFile)
			{
				strcpy( logFiles->logPatientName, [[object valueForKeyPath:@"name"] UTF8String]);
				strcpy( logFiles->logStudyDescription, [[object valueForKeyPath:@"studyName"] UTF8String]);
				strcpy( logFiles->logCallingAET, fromTo);
				logFiles->logStartTime = time (NULL);
				strcpy( logFiles->logMessage, "In Progress");
				logFiles->logNumberReceived = 0;
				logFiles->logNumberTotal = [[object valueForKey:@"noFiles"] intValue];
				logFiles->logEndTime = time (NULL);
				strcpy( logFiles->logType, "Move");
				strcpy( logFiles->logEncoding, "UTF-8");
				
				unsigned int random = (unsigned int)time(NULL);
				sprintf( logFiles->logUID, "%d%s", random, logFiles->logPatientName);
				
				fprintf (pFile, "%s\r%s\r%s\r%ld\r%s\r%s\r%d\r%ld\r%s\r%s\r\%d\r", logFiles->logPatientName, logFiles->logStudyDescription, logFiles->logCallingAET, logFiles->logStartTime, logFiles->logMessage, logFiles->logUID, logFiles->logNumberReceived, logFiles->logEndTime, logFiles->logType, logFiles->logEncoding, logFiles->logNumberTotal);
				
				fclose (pFile);
				strcpy( newdir, dir);
				strcat( newdir, ".log");
				rename( dir, newdir);
			}
		}
	}
}

- (OFCondition)prepareMoveForDataSet:( DcmDataset *)dataset
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSManagedObjectModel *model = [[BrowserController currentBrowser] managedObjectModel];
	NSError *error = nil;
	NSEntityDescription *entity;
	NSPredicate *predicate = [self predicateForDataset:dataset];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	const char *sType;
	dataset->findAndGetString (DCM_QueryRetrieveLevel, sType, OFFalse);
	
	if (strcmp(sType, "STUDY") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Study"];
	else if (strcmp(sType, "SERIES") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Series"];
	else if (strcmp(sType, "IMAGE") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Image"];
	else 
		entity = nil;
	
	[request setEntity:entity];
	
	if( strcmp(sType, "IMAGE") == 0)
		[request setPredicate: [NSPredicate predicateWithFormat:@"compressedSopInstanceUID != NIL"]];
	else
		[request setPredicate: predicate];
	
	error = nil;
	
	NSManagedObjectContext *context = [[BrowserController currentBrowser] managedObjectContext];
	
	[context retain];
	[context lock];
	
	NSArray *array = nil;
	
	OFCondition cond = EC_IllegalParameter;
	
	@try
	{
		array = [context executeFetchRequest:request error:&error];
		
		if( strcmp(sType, "IMAGE") == 0)
		{
			array = [array filteredArrayUsingPredicate: predicate];
		}
		
		if( [array count] == 0)
		{
			// not found !!!!
		}
		
		if (error)
		{
			for( int i = 0 ; i < moveArraySize; i++) free( moveArray[ i]);
			free( moveArray);
			moveArray = nil;
			moveArraySize = 0;
			
			cond = EC_IllegalParameter;
		}
		else
		{
			NSEnumerator *enumerator = [array objectEnumerator];
			id moveEntity;
			
			[self updateLog: array];
			
			NSMutableSet *moveSet = [NSMutableSet set];
			while (moveEntity = [enumerator nextObject])
				[moveSet unionSet:[moveEntity valueForKey:@"paths"]];
			
			NSArray *tempMoveArray = [moveSet allObjects];
			
			/*
			create temp folder for Move paths. 
			Create symbolic links. 
			Will allow us to convert the sytax on copies if necessary
			*/
			
			//delete if necessary and create temp folder. Allows us to compress and deompress files. Wish we could do on the fly
	//		tempMoveFolder = [[NSString stringWithFormat:@"/tmp/DICOMMove_%@", [[NSDate date] descriptionWithCalendarFormat:@"%H%M%S%F"  timeZone:nil locale:nil]] retain]; 
	//		
	//		NSFileManager *fileManager = [NSFileManager defaultManager];
	//		if ([fileManager fileExistsAtPath:tempMoveFolder]) [fileManager removeFileAtPath:tempMoveFolder handler:nil];
	//		if ([fileManager createDirectoryAtPath:tempMoveFolder attributes:nil]) 
	//			NSLog(@"created temp Folder: %@", tempMoveFolder);
	//		
	//		//NSLog(@"Temp Move array: %@", [tempMoveArray description]);
	//		NSEnumerator *tempEnumerator = [tempMoveArray objectEnumerator];
	//		NSString *path;
	//		while (path = [tempEnumerator nextObject]) {
	//			NSString *lastPath = [path lastPathComponent];
	//			NSString *newPath = [tempMoveFolder stringByAppendingPathComponent:lastPath];
	//			[fileManager createSymbolicLinkAtPath:newPath pathContent:path];
	//			[paths addObject:newPath];
	//		}
			
			tempMoveArray = [tempMoveArray sortedArrayUsingSelector:@selector(compare:)];
			
			for( int i = 0 ; i < moveArraySize; i++) free( moveArray[ i]);
			free( moveArray);
			moveArray = nil;
			moveArraySize = 0;
			
			moveArraySize = [tempMoveArray count];
			moveArray = (char**) malloc( sizeof( char*) * moveArraySize);
			for( int i = 0 ; i < moveArraySize; i++)
			{
				const char *str = [[tempMoveArray objectAtIndex: i] UTF8String];
				
				moveArray[ i] = (char*) malloc( strlen( str) + 1);
				strcpy( moveArray[ i], str);
			}
			
			cond = EC_Normal;
		}

	}
	@catch (NSException * e)
	{
		NSLog( @"prepareMoveForDataSet exception");
		NSLog( [e description]);
		NSLog( [predicate description]);
	}

	[context unlock];
	[context release];
	
	// TO AVOID DEADLOCK
	
	BOOL fileExist = YES;
	char dir[ 1024];
	sprintf( dir, "%s", "/tmp/move_process");
	
	int inc = 0;
	do
	{
		int err = unlink( dir);
		if( err  == 0 || errno == ENOENT) fileExist = NO;
		
		usleep( 1000);
		inc++;
	}
	while( fileExist == YES && inc < 100000);
	
	[pool release];
	
	return cond;
}

- (BOOL)findMatchFound
{
	if (findArray) return YES;
	return NO;
}

- (int)moveMatchFound
{
	return moveArraySize;
}

- (OFCondition) nextFindObject:(DcmDataset *)dataset  isComplete:(BOOL *)isComplete
{
	id item;
	
	NSManagedObjectContext *context = [[BrowserController currentBrowser] managedObjectContext];
	
	[context lock];
	
	@try
	{	
		if (item = [findEnumerator nextObject])
		{
			if ([[item valueForKey:@"type"] isEqualToString:@"Series"])
			{
				 [self seriesDatasetForFetchedObject:item dataset:(DcmDataset *)dataset];
			}
			else if ([[item valueForKey:@"type"] isEqualToString:@"Study"])
			{
				[self studyDatasetForFetchedObject:item dataset:(DcmDataset *)dataset];
			}
			else if ([[item valueForKey:@"type"] isEqualToString:@"Image"])
			{
				[self imageDatasetForFetchedObject:item dataset:(DcmDataset *)dataset];
			}
			*isComplete = NO;
		}
		else
			*isComplete = YES;
	}
		
	@catch (NSException * e)
	{
		NSLog( @"******* nextFindObject exception : %@", e);
	}
	
	[context unlock];
	
	return EC_Normal;
}

- (OFCondition)nextMoveObject:(char *)imageFileName
{
	OFCondition ret = EC_Normal;
	
	if( moveArrayEnumerator >= moveArraySize)
	{
		return EC_IllegalParameter;
	}
	
	if( moveArray[ moveArrayEnumerator])
		strcpy(imageFileName, moveArray[ moveArrayEnumerator]);
	else
	{
		NSLog(@"No path");
		ret = EC_IllegalParameter;
	}
	
	moveArrayEnumerator++;
	
	if( logFiles)
	{
		FILE * pFile;
		char dir[ 1024], newdir[1024];
		unsigned int random = (unsigned int)time(NULL);
		sprintf( dir, "%s/%s%d", [[BrowserController currentBrowser] cfixedDocumentsDirectory], "TEMP/move_log_", random);
		pFile = fopen (dir,"w+");
		if( pFile)
		{
			if( moveArrayEnumerator >= moveArraySize)
				strcpy( logFiles->logMessage, "Complete");
			
			logFiles->logNumberReceived++;
			logFiles->logEndTime = time (NULL);
			
			fprintf (pFile, "%s\r%s\r%s\r%ld\r%s\r%s\r%d\r%ld\r%s\r%s\r\%d\r", logFiles->logPatientName, logFiles->logStudyDescription, logFiles->logCallingAET, logFiles->logStartTime, logFiles->logMessage, logFiles->logUID, logFiles->logNumberReceived, logFiles->logEndTime, logFiles->logType, logFiles->logEncoding, logFiles->logNumberTotal);
			
			fclose (pFile);
			strcpy( newdir, dir);
			strcat( newdir, ".log");
			rename( dir, newdir);
		}
	}
	
	if( moveArrayEnumerator >= moveArraySize)
	{
		if( logFiles)
			free( logFiles);
		
		logFiles = nil;
	}
	
	return ret;
}

@end
