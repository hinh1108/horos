/*=========================================================================
 *
 *  Copyright Insight Software Consortium
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0.txt
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *=========================================================================*/
#ifndef __itkAtanRegularizedHeavisideStepFunction_h
#define __itkAtanRegularizedHeavisideStepFunction_h

#include "itkRegularizedHeavisideStepFunction.h"

namespace itk
{
/** \class AtanRegularizedHeavisideStepFunction
 *
 * \brief Atan-based implementation of the Regularized (smoothed) Heaviside functions.
 *
 * \author Mosaliganti K., Smith B., Gelas A., Gouaillard A., Megason S.
 *
 *  This code was taken from the Insight Journal paper:
 *
 *      "Cell Tracking using Coupled Active Surfaces for Nuclei and Membranes"
 *      http://www.insight-journal.org/browse/publication/642
 *      http://hdl.handle.net/10380/3055
 *
 *  That is based on the papers:
 *
 *      "Level Set Segmentation: Active Contours without edge"
 *      http://www.insight-journal.org/browse/publication/322
 *      http://hdl.handle.net/1926/1532
 *
 *      and
 *
 *      "Level set segmentation using coupled active surfaces"
 *      http://www.insight-journal.org/browse/publication/323
 *      http://hdl.handle.net/1926/1533
 *
 *
 * \ingroup ITKCommon
 */
template< typename TInput = float, typename TOutput = double >
class AtanRegularizedHeavisideStepFunction:
  public RegularizedHeavisideStepFunction< TInput, TOutput >
{
public:
  typedef AtanRegularizedHeavisideStepFunction                Self;
  typedef RegularizedHeavisideStepFunction< TInput, TOutput > Superclass;
  typedef SmartPointer< Self >                                Pointer;
  typedef SmartPointer< const Self >                          ConstPointer;

  itkNewMacro(Self);

  itkTypeMacro(AtanRegularizedHeavisideStepFunction, RegularizedHeavisideStepFunction);

  typedef typename Superclass::InputType  InputType;
  typedef typename Superclass::OutputType OutputType;
  typedef typename Superclass::RealType   RealType;

  /** Evaluate at the specified input position */
  virtual OutputType Evaluate(const InputType & input) const;

  /** Evaluate the derivative at the specified input position */
  virtual OutputType EvaluateDerivative(const InputType & input) const;

protected:

  AtanRegularizedHeavisideStepFunction();
  virtual ~AtanRegularizedHeavisideStepFunction();

private:
  /** purposely not implemented */
  AtanRegularizedHeavisideStepFunction(const Self &);
  void operator=(const Self &);
};
}

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkAtanRegularizedHeavisideStepFunction.hxx"
#endif

#endif
