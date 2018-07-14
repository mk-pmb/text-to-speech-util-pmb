using System;
using System.Reflection;

// based on http://www.codeguru.com/article.php/c5881/

namespace listDllTypes {
  class Program {
    static void Main(string[] args) {
      foreach (var dllFilename in args) {
        Console.WriteLine("=== {0} ===", dllFilename);
        Assembly ass = Assembly.LoadFrom(dllFilename);
        Type[] dllTypes = ass.GetTypes();
        foreach (Type ty in dllTypes) {
          Console.WriteLine("  GUID {0}", ty.GUID);
          Console.WriteLine("    fullname:", ty.FullName);
          Console.WriteLine("    namespace:", ty.Namespace);
          Console.WriteLine("    name:", ty.Name);
          Console.WriteLine("    module:", ty.Module);
        }
      }
    }
  }
}
