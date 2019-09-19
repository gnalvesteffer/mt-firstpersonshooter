<Query Kind="Statements" />

var directory = @"D:\Games\minetest-5.0.1-win64\mods\first_person_shooter\textures";
foreach (var filePath in Directory.GetFiles(directory, "*.png"))
{
	var fileInfo = new FileInfo(filePath);
	File.Move(filePath, $@"{fileInfo.DirectoryName}\{fileInfo.Name.ToLower().Replace("(", string.Empty).Replace(")", string.Empty).Replace(" ", ".")}");
}